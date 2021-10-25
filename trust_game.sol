// SPDX-License-Identifier: MIT
    // Description
// The idea is to create a game where a network is initially initialized as the empty network with each player being a node. Links can be formed in the network by agreement. 
// These links are always undirected. The formation of links are done bilaterally, whilst the severing of links are done automatically when nodes are deleted.
// A node can be deleted from the graph by the discretion of other nodes in the game. Each node is allowed to delete exactly one node from the game at any time, as long as it follows the rules of the game.
// The mapping of nodes to the nodes they can delete is referred to as the "kill list" and is always 1-1. When a node is deleted, the node that maps from the deleted node is now mapped from the "killer"'s node.
// If a formation of links is agreed by two parties, and the rules of the game are not violated, the nodes swap kill list mappings.
  
// The rules of the game dictate that:
    // No node is allowed to delete a node that has deleted less nodes than what the "killer" has. 
    // No node is allowed to kill once the game has ended.
    // All networks must be acyclical.

// The nodes that remain after the game has completed are rewarded proportional to the size of their clique (reffered to as group).

    // Pseudocode
// 1. Participate with fee
// 2. The fees are all collected and put into total prize pot.

// 3. Each player's killList mapping is initialized to herself. Each player is given a kill count- initialized at 0.

// 4. Kill function: allow any node i to kill node j as long as node i maps to node j in the killList.
        // Check player[i].killcount <= player[j].killcount
// When someone dies
    // if address points to themselves, do nothing
    // if their address points to someone else, the password is now linked to that account.

// 5. Cartel function: in order to form links, players can bilaterally agree to have their killList mappings swapped.

// 6. The reward calculation should be such that it is more profitable to form a link than to be a single player, but also that killing is profitable as long as it does not decrease
// the group size by more than 1. 
// I.e u(g-1|n-1)>u(g|n) > u(1|n-1)


pragma solidity >0.4.23 <0.7.0;

contract TrustGame {
    struct Player {
        uint32 bodyCount;
        address[] linksTo; // This is who the player has direct links to
        uint group;
        bool alive;
        address requestCartel;
        bool hasRegistered;

    }

    address payable public beneficiary;
    uint public gameEnd;
    bool public ended;
    uint public fee;
    uint public totalPot;
    uint public effectivePlayers;
    uint public groupCount;
    uint public activeGroupCount;

    mapping(address => Player) public players;
    mapping(address => address) public killList;
    mapping(uint => address[]) public groupList;


    mapping(address => uint) public withdrawableFunds;

    event GameEvaluated(uint effectivePlayers, uint totalPot);
    event GameEnded(uint time);

    modifier onlyBefore(uint _time) { require(now < _time); _; }
    modifier onlyAfter(uint _time) { require(now > _time); _; }

    constructor(
        uint _gameTime,
        uint _fee
       
    ) public {
        gameEnd = now + _gameTime;
        fee = _fee;
        totalPot = 0;
        groupCount = 0;
    }

    
    function enterGame()
        public
        payable
        onlyBefore(gameEnd)
    {
        require(msg.value >= fee, "Your payment did not meet the fee requirement");
        require(msg.value < 2*fee, "Seems like you are paying more than twice the fee, this is to help you avoid overspending");
        require(msg.value + totalPot < 10 ** 50, "the pot size is getting dangerously large, no more players allowed");
        require(!players[msg.sender].hasRegistered, "You can only enter the game once");
        Player storage _player = players[msg.sender];
            _player.hasRegistered = true;
            // increment the group number and assign this to the player
            groupCount++;
            activeGroupCount ++;
            _player.group = groupCount;
            _player.bodyCount =  0;
            _player.alive = true;

        //Add player to a group involving only himself
        groupList[_player.group].push(msg.sender);
        
        
        // Iniitalize killList so that player can only kill himself
        killList[msg.sender] = msg.sender;


        totalPot += msg.value;
        
    }
    
    function kill()
        public
        onlyBefore(gameEnd)
    {
        require(players[msg.sender].alive == true, "No kills from the grave I'm afraid");
        Player storage _killer = players[msg.sender];
        address _addressToKill = killList[msg.sender];
        Player storage _playerToKill = players[_addressToKill];
        assert(_playerToKill.alive == true);
        require(_playerToKill.bodyCount >= _killer.bodyCount, "You can only kill someone with a killcount greater than or equal to your own");
        _playerToKill.alive = false;
        _killer.bodyCount += 1;

        // The killer takes control over the victim's victim.
        killList[msg.sender] = killList[_addressToKill];


        //TODO: All ties must be severed and new groups created where needed
        
        //The victim's victim now needs a new group, and the whole group needs to be updated recursively
        breakLink(_addressToKill, msg.sender);
    }


    function breakLink(address _deadLink, address _killer) internal {
        assert(groupList[groupCount+1].length == 0);
        // Note that this could include the killer as well. Make sure the killer isn't removed from his own group
        address[] memory linksToBreak = players[_deadLink].linksTo;
        for (uint i = 0; i < linksToBreak.length; i++) {
            if (linksToBreak[i] == _killer){
                continue;
            }
            else {
                // Assign to new group
                groupCount ++;
                changeGroup(linksToBreak[i], groupCount, _deadLink);
            }
        }
        delete players[_deadLink].linksTo;
    
    }
    
    function changeGroup(address fromAddress, uint toGroup, address deadLink) internal {
        
        Player storage changer = players[fromAddress];
        
        uint from_group = changer.group;
        
        changer.group = toGroup;

        groupList[toGroup].push(fromAddress);

        address[] memory linksToChange = changer.linksTo;

        for (uint i = 0; i < linksToChange.length; i++) {
            if (linksToChange[i] == deadLink) {
                delete linksToChange[i];
            }
            else if (players[linksToChange[i]].group == toGroup){
                continue;
            }
            else {
                changeGroup(linksToChange[i], toGroup, deadLink);
            }
        }

        delete groupList[from_group];
        activeGroupCount --;
    }

    function requestCartel(address _receiverAddress) public {
        // Check so that receiver is an address
        // Also change naming of receiver
        Player storage receiver = players[_receiverAddress];
        Player storage sender = players[msg.sender];
        require(receiver.alive, "You can only request a cartel with an alive player");
        sender.requestCartel = _receiverAddress;
        if (receiver.requestCartel == msg.sender){
            require(sender.group != receiver.group, "The two of you are already in the same group, cannot cartel further"); 
            if (receiver.group < sender.group) {
                // Sending deadLink = address(0) since nobody has died in a cartel formation, so no need to delete links
                changeGroup(msg.sender, receiver.group, address(0));
            }
            else {
                changeGroup(_receiverAddress, sender.group, address(0));
            }
            
            // Switch who kills who
            killList[msg.sender] = killList[_receiverAddress];
            killList[_receiverAddress] = killList[msg.sender];
            

            //reset requestCartel
            players[msg.sender].requestCartel = address(0);
            players[_receiverAddress].requestCartel = address(0);
        }
    }
    
    /// This evaluates the payouts and allows it to be withdrawn from each of the winning players.
    //TODO: improve such that it is done automatically and does not need to be called by someone?
    function evaluate()
        internal
        onlyAfter(gameEnd)
        returns(bool)
    {
        // Is this safe enough?
        assert(ended);
        assert(effectivePlayers == 0);      
          
        // We need to evaluate all the weights and which 
        for (uint i = 0; i < groupCount + 1; i++){
            effectivePlayers += groupList[i].length;
        }
        emit GameEvaluated(effectivePlayers, totalPot);

        return true;
    }

    /// Withdraw a bid that was overbid.
    function withdraw() public {
        Player storage _finisher = players[msg.sender];
        require(effectivePlayers != 0, "the evaluate function has not been called");
        require(_finisher.alive == true, "You either died in the game or have already withdrawn. There is nothing for you to withdraw" );
        uint weight = groupList[_finisher.group].length;
        uint amount = totalPot/effectivePlayers * weight;
        if (amount > 0) {
            
            // Player dies when she withdraws her winnings
            _finisher.alive = false;

            msg.sender.transfer(amount);
        }
    }

    /// End the game and allow it to be evaluated
    function endGame()
        public
        onlyAfter(gameEnd)
    {
        require(!ended);
        emit GameEnded(now);

        // Is this safe??
        ended = evaluate();
    }
}