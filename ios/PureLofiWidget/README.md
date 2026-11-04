# PureLofi widget (iOS, #144)

The Swift is here; the Xcode target is not, because adding a target means
editing `project.pbxproj`, which is done in Xcode, not by hand.

1. Xcode → File → New → Target → **Widget Extension**, name it
   `PureLofiWidget`, untick "Include Configuration App Intent". Replace the
   generated Swift with `PureLofiWidget.swift` from this folder.
2. Signing & Capabilities → add **App Groups** with `group.app.purelofi`
   to **both** the Runner target and the widget target.
3. Deployment target of the widget: iOS 17 (interactive `Button(intent:)`).

The app already writes `room`, `track`, `artist`, `cover`, `playing` into
that group (`HomeWidgetServiceImpl`) and reloads the `PureLofiWidget` kind.
