import Principal "mo:base/Principal";
import Utils "../helpers/Utils";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";

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
            #AmountTooSmall;
        };
    };

    public func transfer(recipient:Text, amount:Nat): async TxReceipt {
        await canister.transfer(Principal.fromText(recipient), amount);
    };

    private let canister = actor(Constants.dip20Canister) : actor { 
        transfer: (Principal, Nat)  -> async TxReceipt;
    };
}
