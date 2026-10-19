/// A usage rate the server learnt (`zad_consumption`, written by
/// `zad_recompute_consumption` from the pantry's −/+ and the bot's «خلص؟»).
library;

/// Per day, and whether it is confirmed (three drops on two days) or a first
/// estimate.
typedef ConsumptionRate = ({double perDay, bool known});

/// How the rates are keyed — the server joins names on `lower(trim())`.
String rateKey(String itemName) => itemName.trim().toLowerCase();
