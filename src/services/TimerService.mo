import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";

module {

    public func start_proposal_timer(time:Nat64): async () {
        await canister.start_proposal_timer(time);
    };

    private let canister = actor(Constants.timerCanister) : actor { 
        start_proposal_timer : shared (Nat64) -> async ();
    };
}