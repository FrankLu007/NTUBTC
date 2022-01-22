// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ModelTrainer is ERC1155 {
    uint256 public constant share = 0;

    event submit(
        address indexed director,
        uint indexed index,
        address indexed destination,
        uint value
    );
    event confirm(address indexed director, uint indexed index);
    event revoke(address indexed director, uint indexed index);
    event execute(address indexed director, uint indexed index);

    address[] public directors;
    address creator;
    mapping(address => bool) public isDirector;
    mapping(uint => mapping(address => bool)) public isConfirmed;
    uint public numConfirmationsRequired;
    
    struct Transaction {
        address destination;
        uint value;
        bytes data;
        bool complete;
        uint numConfirmations;
    }

    Transaction[] public trans;

    modifier DirectorCheck() {
        require(isDirector[msg.sender], "not a director");
        _;
    }

    modifier TargetCheck(uint TargetIndex) {
        require(TargetIndex < trans.length, "target does not exist");
        _;
    }

    modifier incomplete(uint TargetIndex) {
        require(!trans[TargetIndex].complete, "tx already executed");
        _;
    }

    modifier unconfirmed(uint TargetIndex) {
        require(!isConfirmed[TargetIndex][msg.sender], "has already confirmed");
        _;
    }

    constructor(address[] memory _directors, uint _numConfirmationsRequired, uint _originalShare) 
        public
        ERC1155("https://raw.githubusercontent.com/FrankLu007/NTUBTC/main/{id}.json")
    {
        require(_directors.length > 0, "directors required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _directors.length, "invalid number of required confirmations");

        for (uint i = 0; i < _directors.length; i++) {
            address director = _directors[i];

            require(director != address(0), "invalid address");
            if (isDirector[director])
                continue;

            isDirector[director] = true;
            directors.push(director);
        }

        require(isDirector[msg.sender], "Creator should be one of directors.");
        require(_numConfirmationsRequired <= directors.length, "invalid number of required confirmations");
        
        creator = msg.sender;
        numConfirmationsRequired = _numConfirmationsRequired;
        _mint(msg.sender, share, _originalShare, "");
    }

    function getShare(address addr)
        view public returns (uint256)
    {
        return balanceOf(addr, 0);
    }

    function burnShare(address addr, uint value)
        public
        DirectorCheck
    {
        _burn(addr, share, value);
    }

    function mintShare(uint value)
        public
        DirectorCheck
    {
        _mint(creator, share, value, "");
    }

    function submitTransaction(
        address _destination,
        uint _value
    ) public {
        uint remain = balanceOf(creator, share);
        require(remain >= _value, "not enough stocks to give");
        uint index = trans.length;

        trans.push(
            Transaction({
                destination: _destination,
                value: _value,
                data: "",
                complete: false,
                numConfirmations: 0
            })
        );

        emit submit(msg.sender, index, _destination, _value);
    }

    function ConfirmTransaction(uint index)
        public
        DirectorCheck
        TargetCheck(index)
        incomplete(index)
        unconfirmed(index)
    {
        Transaction storage transaction = trans[index];
        transaction.numConfirmations += 1;
        isConfirmed[index][msg.sender] = true;

        if (transaction.numConfirmations >= numConfirmationsRequired) {
            ExecuteTransaction(index);
        }

        emit confirm(msg.sender, index);
    }

    function ExecuteTransaction(uint index)
        private
        TargetCheck(index)
        incomplete(index)
    {
        Transaction storage t = trans[index];

        require(t.numConfirmations >= numConfirmationsRequired, "not enough confirmations");

        t.complete = true;

        safeTransferFrom(creator, t.destination, share, t.value, t.data);

        emit execute(msg.sender, index);
    }

    function revokeConfirmation(uint index)
        public
        DirectorCheck
        TargetCheck(index)
        incomplete(index)
    {
        Transaction storage t = trans[index];

        require(isConfirmed[index][msg.sender], "transaction is not confirmed");

        t.numConfirmations -= 1;
        isConfirmed[index][msg.sender] = false;

        emit revoke(msg.sender, index);
    }

    function getDirectors() public view returns (address[] memory) { return directors; }

    function getTransactionCount() public view returns (uint) { return trans.length; }

    function getTransaction(uint index)
        public
        view
        returns (
            address destination,
            uint value,
            bytes memory data,
            bool complete,
            uint numConfirmations
        )
    {
        Transaction storage t = trans[index];

        return (t.destination, t.value, t.data, t.complete, t.numConfirmations);
    }
}