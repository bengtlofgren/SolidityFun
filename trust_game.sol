  // Pseudocode

// Should a public key be available for encryption where the private key is revealed at the end of the game?

// 1. Participate with fee, hash of secret message using contract public key -- 
//looks like this does not work so instead just use keccak256

// 2. The fees are all collected and put into total prize pot. In order to release this pot, 
// the unlockWithdraw function must be called, with the correct password. The withdraw function will allow all 
// remaining participants to withdraw their respective amounts.

// Each user is given a kill count- initialized at 0, and addresses are initially mapped to the hash of their own password.

// 3. The withdraw password is a function of the players remaining. Perhaps something like submitting a number 
// such that when sent through ECDSA produces a public key with consecutive number of zeros. Or could just hardcode it? 
// Could allow the withdrawer to set a parameter that affects distribution of funds as well?

// 4. Kill function: allow any player to be killed if their password is revealed. Player i can only kill player j if 
        // player[i].killcount <= player[j].killcount
// If the password does not correspond to a hash, the killer dies -- but why would a killer ever submit an incorrect hash? 
// Can't they find it in the blockchain? - Yes
//      Everybody has a kill count. This becomes relevant later. 

// 5. Merge function, in order to merge, players can bilaterally agree to have their secret message addresses swapped.
// They now have the capability of killing each other. However, the weight on each node's withdrawal
// is determined by the length of their network. I should work out the math so that it is profitable 
// for any one person to cut a link, but that the whole network is always more profitable than a single node for everyone.

// I.e u(g-1|n-1)>u(g|n) > u(1|n-1)

// When someone dies
    // if address points to themselves, do nothing
    // if their address points to someone else, the password is now linked to that account.
    
// How do we avoid people making multiple accounts? :/// Make bigger networks?

pragma solidity >0.4.23 <0.7.0;

contract TrustGame {
    struct Player {
        uint32 bodyCount;
        bytes32 secretHash[];
        bool alive;
        address requestCartel;
    }

    address payable public beneficiary;
    uint public gameEnd;
    uint public revealEnd;
    bool public ended;
    uint public fee;
    uint public totalPot;
    uint public playerCount;

    mapping(address => Player) public players;
    mapping(bytes32 secretHash => address) public killList;

    // address public highestBidder;
    // uint public highestBid;

    // Allowed withdrawals of previous bids
    mapping(address => uint) pendingReturns;

    event AuctionEnded(address winner, uint highestBid);

    /// Modifiers are a convenient way to validate inputs to
    /// functions. `onlyBefore` is applied to `bid` below:
    /// The new function body is the modifier's body where
    /// `_` is replaced by the old function body.
    modifier onlyBefore(uint _time) { require(now < _time); _; }
    modifier onlyAfter(uint _time) { require(now > _time); _; }

    constructor(
        uint _gameTime,
        uint _revealTime,
        uint _fee
       
    ) public {
        gameEnd = now + _gameTime;
        revealEnd = gameEnd + _revealTime;
        fee = _fee;
        totalPot = 0;
        playerCount = 0;
    }

    
    function enterGame(bytes32 _secretHash)
        public
        payable
        onlyBefore(gameEnd)
    {
        require(msg.value >= fee, "Your payment did not meet the fee requirement");
        require(msg.value < 2*fee, "Seems like you are paying more than twice the fee, this is to help you avoid overspending");
        require(msg.value += totalPot < 10 ** 50, "the pot size is getting dangerously large, no more players allowed");
        require(players[msg.sender].secretHash != 0, "You can only enter the game once");
        var player = players[msg.sender];
            player.secretHash = _secret;
            player.bodyCount =  0;
            player.alive = true;
        
        // Iniitalize killList so that player can only kill himself
        killList(_secret) = msg.sender
        totalPot += msg.value;
        
    }
    
    function kill(bytes32 _secret)
        public
        onlyBefore(gameEnd)
    {
        require(players(msg.sender).alive == true, "No kills from the grave I'm afraid");
        Player _killer = players(msg.sender);
        bytes32 _secretHash = keccak256(abi.encode(_secret));
        address _addressToKill = killList(_secretHash);
        Player _playerToKill = players(_addressToKill);
        if (_playerToKill.alive = true && _playerToKill.bodyCount >= _killer.bodyCount) {
            _playerToKill.alive = false;
            _killer.bodyCount += 1;
        }
    }
    
    function requestCartel(address _receiver) public {
        // Check so that receiver is an address 
        require(players[_receiver].alive, "You can only request a cartel with an alive player")
        players[msg.sender].requestCartel = _receiver;
        if (players[_receiver].requestCartel == msg.sender){
            bytes32 senderHash = players[msg.sender].secretHash[players[msg.sender].secretHash.length - 1]
            bytes32 receiverHash = players[_receiver].secretHash[players[_receiver].secretHash.length - 1]
            
            // Prevent cycles
            // TODO:improve efficiency here, no need to loop through all of i twice
            uint minLength = min(players[msg.sender].secretHash.length, players[_receiver].secretHash.length)
            // uint maxLength = max(players[msg.sender].secretHash.length, players[_receiver].secretHash.length)
            
            for (uint i = 0; i < minLength; i++) {
                require(receiverHash != players[msg.sender].secretHash[i], "this switch would create a loop, not allowed")
                require(senderHash != players[_receiver].secretHash[i], "this switch would create a loop, not allowed")
            }
            if (players[msg.sender].secretHash.length > players[_receiver].secretHash.length){
                for (uint i = minLength - 1; i < players[msg.sender].secretHash.length; i++) {
                    require(receiverHash != players[msg.sender].secretHash[i], "this switch would create a loop, not allowed")
                }
            else {
                for (uint i = minLength - 1; i < players[_receiver].secretHash.length; i++) {
                    require(receiverHash != players[_receiver].secretHash[i], "this switch would create a loop, not allowed")
                }
            }
            
            // Switch who kills who
            killList[senderHash] = players[_receiver]
            killList[receiverHash] = players[msg.sender]
            
            // Add the vulnerable secret hash to the end of the stack for each player
            players[msg.sender].secretHash.push(receiverHash)
            players[_receiver].secretHash.push(senderHash)
            
            //reset requestCartel
            players[msg.sender].requestCartel = 0;
            players[_receiver].requestCartel = 0;
        }
    }
    
    function max(uint a, uint b) internal {
        if (b > a) {
            return b
        }
        return a
    }
    function min(uint a, uint b) internal {
        if (b > a) {
            return a
        }
        return b
    }
    /// Reveal your blinded bids. You will get a refund for all
    /// correctly blinded invalid bids and for all bids except for
    /// the totally highest.
    function reveal(
        uint[] memory _values,
        bool[] memory _fake,
        bytes32[] memory _secret
    )
        public
        onlyAfter(biddingEnd)
        onlyBefore(revealEnd)
    {
        uint length = bids[msg.sender].length;
        require(_values.length == length);
        require(_fake.length == length);
        require(_secret.length == length);

        uint refund;
        for (uint i = 0; i < length; i++) {
            Bid storage bidToCheck = bids[msg.sender][i];
            (uint value, bool fake, bytes32 secret) =
                    (_values[i], _fake[i], _secret[i]);
            if (bidToCheck.blindedBid != keccak256(abi.encodePacked(value, fake, secret))) {
                // Bid was not actually revealed.
                // Do not refund deposit.
                continue;
            }
            refund += bidToCheck.deposit;
            if (!fake && bidToCheck.deposit >= value) {
                if (placeBid(msg.sender, value))
                    refund -= value;
            }
            // Make it impossible for the sender to re-claim
            // the same deposit.
            bidToCheck.blindedBid = bytes32(0);
        }
        msg.sender.transfer(refund);
    }

    // This is an "internal" function which means that it
    // can only be called from the contract itself (or from
    // derived contracts).
    function placeBid(address bidder, uint value) internal
            returns (bool success)
    {
        if (value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            // Refund the previously highest bidder.
            pendingReturns[highestBidder] += highestBid;
        }
        highestBid = value;
        highestBidder = bidder;
        return true;
    }

    /// Withdraw a bid that was overbid.
    function withdraw() public {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `transfer` returns (see the remark above about
            // conditions -> effects -> interaction).
            pendingReturns[msg.sender] = 0;

            msg.sender.transfer(amount);
        }
    }

    /// End the auction and send the highest bid
    /// to the beneficiary.
    function auctionEnd()
        public
        onlyAfter(revealEnd)
    {
        require(!ended);
        emit AuctionEnded(highestBidder, highestBid);
        ended = true;
        beneficiary.transfer(highestBid);
    }
}