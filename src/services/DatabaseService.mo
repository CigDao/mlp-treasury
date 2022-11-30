import Constants "../Constants";

module {

    public func getCanistersByPK(canisterId:Text,pk:Text) : async [Text] {
        let canister = actor(canisterId) : actor { 
            getCanistersByPK: (Text)  -> async [Text];
        };

        await canister.getCanistersByPK(pk);
    };

    public let canister = actor(Constants.databaseCanister) : actor { 
        getCanistersByPK: (Text) -> async [Text]; 
    };
}
