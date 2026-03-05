# Bloom OS — build, test, and deploy

image := "bloom-os:latest"
output := "os/output"
bib := "quay.io/centos-bootc/bootc-image-builder:latest"
ovmf := "/usr/share/edk2/ovmf/OVMF_CODE.fd"
ovmf_vars := "/usr/share/edk2/ovmf/OVMF_VARS.fd"
registry := env("BLOOM_REGISTRY", "ghcr.io/alexradunet")
remote_image := registry + "/bloom-os:latest"

# Build the container image
build:
	podman build -f os/Containerfile -t {{ image }} .

# Generate qcow2 disk image via bootc-image-builder
qcow2: build
	mkdir -p {{ output }}
	sudo podman run --rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v ./os/bib-config.toml:/config.toml:ro \
		-v ./{{ output }}:/output \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		{{ bib }} \
		--type qcow2 --local {{ image }}

# Generate anaconda-iso installer via bootc-image-builder
iso: build
	mkdir -p {{ output }}
	sudo podman run --rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v ./os/bib-config.toml:/config.toml:ro \
		-v ./{{ output }}:/output \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		{{ bib }} \
		--type anaconda-iso --local {{ image }}

# Boot qcow2 in QEMU (graphical + SSH on port 2222)
vm:
	qemu-system-x86_64 \
		-machine q35 \
		-cpu host \
		-enable-kvm \
		-m 4G \
		-smp 2 \
		-drive if=pflash,format=raw,readonly=on,file={{ ovmf }} \
		-drive if=pflash,format=raw,snapshot=on,file={{ ovmf_vars }} \
		-drive file={{ output }}/qcow2/disk.qcow2,format=qcow2,if=virtio \
		-netdev user,id=net0,hostfwd=tcp::2222-:22 \
		-device virtio-net-pci,netdev=net0 \
		-display gtk

# Boot qcow2 in QEMU serial-only mode (no GUI)
vm-serial:
	qemu-system-x86_64 \
		-machine q35 \
		-cpu host \
		-enable-kvm \
		-m 4G \
		-smp 2 \
		-drive if=pflash,format=raw,readonly=on,file={{ ovmf }} \
		-drive if=pflash,format=raw,snapshot=on,file={{ ovmf_vars }} \
		-drive file={{ output }}/qcow2/disk.qcow2,format=qcow2,if=virtio \
		-netdev user,id=net0,hostfwd=tcp::2222-:22 \
		-device virtio-net-pci,netdev=net0 \
		-nographic \
		-serial mon:stdio

# SSH into the running VM
vm-ssh:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 bloom@localhost

# Kill the running QEMU VM
vm-kill:
	pkill -f "qemu-system-x86_64.*disk.qcow2" || true

# Remove generated images
clean:
	rm -rf {{ output }}

# Push built image to GHCR
push-ghcr: build
	podman tag {{ image }} {{ remote_image }}
	podman push {{ remote_image }}

# Generate ISO with GHCR target-imgref for OTA updates
iso-production: build
	mkdir -p {{ output }}
	sudo podman run --rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v ./os/bib-config.toml:/config.toml:ro \
		-v ./{{ output }}:/output \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		{{ bib }} \
		--type anaconda-iso --target-imgref {{ remote_image }} --local {{ image }}

# Push a service package as OCI artifact
svc-push name:
	cd services/{{ name }} && oras push {{ registry }}/bloom-svc-{{ name }}:latest \
		--annotation "org.opencontainers.image.title=bloom-{{ name }}" \
		--annotation "org.opencontainers.image.source=https://github.com/alexradunet/bloom" \
		$(find quadlet -type f | sed 's|.*|&:application/vnd.bloom.quadlet|') \
		SKILL.md:text/markdown

# Pull and install a service package locally (for testing)
svc-install name:
	mkdir -p /tmp/bloom-svc-{{ name }}
	oras pull {{ registry }}/bloom-svc-{{ name }}:latest -o /tmp/bloom-svc-{{ name }}/
	cp /tmp/bloom-svc-{{ name }}/quadlet/* ~/.config/containers/systemd/
	mkdir -p ~/Garden/Bloom/Skills/{{ name }}
	cp /tmp/bloom-svc-{{ name }}/SKILL.md ~/Garden/Bloom/Skills/{{ name }}/SKILL.md
	systemctl --user daemon-reload
	rm -rf /tmp/bloom-svc-{{ name }}

# Install host dependencies
deps:
	sudo dnf install -y just qemu-system-x86 edk2-ovmf
