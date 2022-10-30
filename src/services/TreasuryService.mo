import Principal "mo:base/Principal";
import Utils "../helpers/Utils";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";
import Result "mo:base/Result";
import Request "../treasury/models/Request";

module {

    private type ErrorMessage = { #message : Text;};
    private type RequestDraft = Request.RequestDraft;

    public func approveRequest(id : Nat32): async Result.Result<(), ErrorMessage> {
        await canister.approveRequest(id);
    };

    public func createRequest(request : RequestDraft): async Nat32 {
        await canister.createRequest(request);
    };

    private let canister = actor(Constants.treasuryCanister) : actor { 
        approveRequest : shared (Nat32) -> async Result.Result<(), ErrorMessage>;
        createRequest : shared (RequestDraft) -> async Nat32;
    };
}