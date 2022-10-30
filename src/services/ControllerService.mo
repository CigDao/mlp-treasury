import Principal "mo:base/Principal";
import Utils "../helpers/Utils";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";
import Blob "mo:base/Blob";

module {

    public type TxReceipt = {
        #Ok: Nat;
        #Err: {
            #InsufficientAllowance;
            #InsufficientBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other: Text;
            #BlockUsed;
            #ActiveProposal;
            #AmountTooSmall;
        };
    };

    public func upgradeDao(wasm:Blob,arg:Blob): async () {
        await canister.upgradeDao(wasm, arg);
    };

    private let canister = actor(Constants.controllerCanister) : actor { 
        upgradeDao : shared (Blob, Blob) -> async ();
    };
}