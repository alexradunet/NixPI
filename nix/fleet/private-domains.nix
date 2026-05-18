{ lib }:
let
  exposure = import ./exposure.nix;

  isPrivateAccess =
    route:
    (route.enable or false)
    && lib.elem (route.access or "private") [
      "private"
      "public"
    ];

  hostCode = exposure.host.code or { };
  hostDav = exposure.host.dav or { };

  hostCodeDomains = lib.optional (isPrivateAccess hostCode && hostCode ? domain) hostCode.domain;

  hostDavDomains = lib.optional (isPrivateAccess hostDav && hostDav ? domain) hostDav.domain;

  privateDomainExclusions = exposure.privateDomainExclusions or [ ];
in
lib.subtractLists privateDomainExclusions (lib.unique (hostCodeDomains ++ hostDavDomains))
