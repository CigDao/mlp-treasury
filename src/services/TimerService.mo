import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";

module {

    public func start_proposal_timer(time:Nat64): async () {
        await canister.start_proposal_timer(time);
    };

    public func timer_active(): async Nat64 {
        await canister.timer_active();
    };

    private let canister = actor(Constants.timerCanister) : actor { 
        start_proposal_timer : shared (Nat64) -> async ();
        timer_active: query() -> async Nat64;
    };
}