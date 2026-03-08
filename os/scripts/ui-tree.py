#!/usr/bin/env python3
"""Walk AT-SPI2 accessibility tree and output JSON.

Usage:
    ui-tree.py              # full tree
    ui-tree.py --app NAME   # filter by application name
"""
import json
import sys

import pyatspi


def node_to_dict(node, depth=0, max_depth=10):
    """Convert an AT-SPI2 accessible node to a dictionary."""
    if depth > max_depth:
        return None
    try:
        role = node.getRoleName()
        name = node.name or ""
        state_set = node.getState()
        states = []
        for s in pyatspi.StateType._enum_lookup.values():
            if state_set.contains(s):
                states.append(str(s).split("_", 2)[-1].lower())

        result = {
            "role": role,
            "name": name,
            "states": states,
        }

        # Add position/size if available
        try:
            component = node.queryComponent()
            if component:
                bbox = component.getExtents(pyatspi.DESKTOP_COORDS)
                result["bounds"] = {
                    "x": bbox.x,
                    "y": bbox.y,
                    "width": bbox.width,
                    "height": bbox.height,
                }
        except (NotImplementedError, AttributeError):
            pass

        # Add text content if available
        try:
            text_iface = node.queryText()
            if text_iface:
                text = text_iface.getText(0, min(text_iface.characterCount, 500))
                if text.strip():
                    result["text"] = text
        except (NotImplementedError, AttributeError):
            pass

        # Add value if available
        try:
            value_iface = node.queryValue()
            if value_iface:
                result["value"] = value_iface.currentValue
        except (NotImplementedError, AttributeError):
            pass

        # Recurse into children
        children = []
        for i in range(node.childCount):
            try:
                child = node.getChildAtIndex(i)
                if child:
                    child_dict = node_to_dict(child, depth + 1, max_depth)
                    if child_dict:
                        children.append(child_dict)
            except Exception:
                continue
        if children:
            result["children"] = children

        return result
    except Exception:
        return None


def main():
    app_filter = None
    if "--app" in sys.argv:
        idx = sys.argv.index("--app")
        if idx + 1 < len(sys.argv):
            app_filter = sys.argv[idx + 1].lower()

    desktop = pyatspi.Registry.getDesktop(0)
    apps = []

    for i in range(desktop.childCount):
        try:
            app = desktop.getChildAtIndex(i)
            if app is None:
                continue
            app_name = app.name or f"app-{i}"
            if app_filter and app_filter not in app_name.lower():
                continue
            app_dict = node_to_dict(app)
            if app_dict:
                apps.append(app_dict)
        except Exception:
            continue

    json.dump(apps, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
