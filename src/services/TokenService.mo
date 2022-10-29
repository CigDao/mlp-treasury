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

    public func allowance(owner:Principal, spender:Principal): async Nat {
        await canister.allowance(owner, spender);
    };

    public func transfer(to:Principal, amount:Nat): async TxReceipt {
        await canister.transfer(to, amount);
    };

    public func transferFrom(from:Principal, to:Principal, amount:Nat): async TxReceipt {
        await canister.transferFrom(from, to, amount);
    };

    public func chargeTax(from:Principal, amount:Nat): async TxReceipt {
        await canister.chargeTax(from, amount);
    };

    private let canister = actor(Constants.dip20Canister) : actor { 
        allowance : shared query (Principal, Principal) -> async Nat;
        transfer: (Principal, Nat)  -> async TxReceipt;
        transferFrom : shared (Principal, Principal, Nat) -> async TxReceipt;
        chargeTax : shared (Principal, Nat) -> async TxReceipt;
    };
}