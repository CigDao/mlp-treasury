import Principal "mo:base/Principal";
import Utils "../helpers/Utils";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";
import Proposal "../dao/models/Proposal";

module {

    private type Proposal = Proposal.Proposal; 

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

    public func executeProposal(): async () {
        await canister.executeProposal();
    };

    public func getProposal(): async ?Proposal {
        await canister.getProposal();
    };

    public func getExecutionTime(): async Int {
        await canister.getExecutionTime();
    };

    private let canister = actor(Constants.daoCanister) : actor { 
        executeProposal : shared () -> async ();
        getProposal : shared () -> async ?Proposal;
        getExecutionTime : shared () -> async Int;
    };
}
