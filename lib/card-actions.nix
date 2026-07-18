# lib/card-actions.nix — THE closed registry of commands a card's `run` action
# may invoke. This is the entire security model for card actions: a model (or a
# lane) can only ever propose `run <name>` where <name> is a KEY in this set —
# there is NO free-form exec, ever, and the renderer never runs a string it
# didn't look up here. Two consumers read it by construction:
#   lib/claude-script.nix  → claudeos_card REJECTS a `run` name not in this set
#                            (validation at write time)
#   home/hyprland.nix      → generates CardActions.qml (name → argv) that
#                            CardRenderer.qml execDetaches on tap
# Adding a card-invokable command is a one-line, reviewed diff here — ring 1,
# never something a card's payload can introduce.
#
# Shape: <name> = { label = "human label"; command = [ "argv0" "arg1" … ]; };
{
  open-desk = {
    label = "Open the morning desk";
    command = [ "claudeos-desk-open" ];
  };
}
