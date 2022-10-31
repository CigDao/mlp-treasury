import Principal "mo:base/Principal";
import Utils "../helpers/Utils";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";

module {

    public func updateTransactionPercentage(value:Float): async () {
        await canister.updateTransactionPercentage(value);
    };

    public func updateBurnPercentage(value:Float): async () {
        await canister.updateBurnPercentage(value);
    };

    public func updateReflectionPercentage(value:Float): async () {
        await canister.updateReflectionPercentage(value);
    };

    public func updateTreasuryPercentage(value:Float): async () {
        await canister.updateTreasuryPercentage(value);
    };

    public func updateMarketingPercentage(value:Float): async () {
        await canister.updateMarketingPercentage(value);
    };

    public func updateMaxHoldingPercentage(value:Float): async () {
        await canister.updateMaxHoldingPercentage(value);
    };

    private let canister = actor(Constants.communityCanister) : actor { 
        updateTransactionPercentage : shared (Float) -> async ();
        updateBurnPercentage : shared (Float) -> async ();
        updateReflectionPercentage : shared (Float) -> async ();
        updateTreasuryPercentage : shared (Float) -> async ();
        updateMarketingPercentage : shared (Float) -> async ();
        updateMaxHoldingPercentage : shared (Float) -> async ();
    };
}