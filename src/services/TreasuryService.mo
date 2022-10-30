import Principal "mo:base/Principal";
import Utils "../helpers/Utils";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";
import Result "mo:base/Result";

module {

    private type ErrorMessage = { #message : Text;};

    public func approveRequest(id : Nat32): async Result.Result<(), ErrorMessage> {
        await canister.approveRequest(id);
    };

    private let canister = actor(Constants.treasuryCanister) : actor { 
        approveRequest : shared (Nat32) -> async Result.Result<(), ErrorMessage>;
    };
}