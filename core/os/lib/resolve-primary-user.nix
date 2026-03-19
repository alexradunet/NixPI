{ lib, config }:

let
  serviceUser = config.nixpi.serviceUser;
  users = config.users.users;
  userNames = builtins.attrNames users;

  isManagedHuman = name:
    let
      user = builtins.getAttr name users;
      home = user.home or "";
    in
      name != serviceUser
      && (user.isNormalUser or false)
      && lib.hasPrefix "/home/" home;

  detectedUsers = builtins.filter isManagedHuman userNames;
  resolvedPrimaryUser =
    if config.nixpi.primaryUser != "" then
      config.nixpi.primaryUser
    else if config.nixpi.install.autoDetectPrimaryUser && lib.length detectedUsers == 1 then
      builtins.head detectedUsers
    else
      "";

  resolvedPrimaryHome =
    if config.nixpi.primaryHome != "" then
      config.nixpi.primaryHome
    else if resolvedPrimaryUser != "" then
      "/home/${resolvedPrimaryUser}"
    else
      "";
in
{
  inherit detectedUsers resolvedPrimaryUser resolvedPrimaryHome;
}
