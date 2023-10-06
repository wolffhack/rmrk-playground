// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract RotamAccess {
    enum AccessLevel {
        None,
        //Taller autorizado por rotam
        Taller,
        //Sucursal de rotam
        Sucursal,
        //lawyer
        Lawyer,
        //rotam
        Owner
    }

    mapping(address => AccessLevel) public accessLevels;

    event TallerAdded(address taller);
    event MemberRemoved(address member);
    event SucursalAdded(address sucursal);
    event LawyerAdded(address lawyer);

    address public owner;

    constructor() {
        owner = msg.sender;
        accessLevels[msg.sender] = AccessLevel.Owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function delRotamAccess(address _member) public onlyOwner {
        accessLevels[_member] = AccessLevel.None;
        emit MemberRemoved(_member);
    }

    function addTaller(address _taller) public onlyOwner {
        accessLevels[_taller] = AccessLevel.Taller;
        emit TallerAdded(_taller);
    }
    
    function addSucursal(address _sucursal) public onlyOwner {
        accessLevels[_sucursal] = AccessLevel.Sucursal;
        emit SucursalAdded(_sucursal);
    }

    function addLawyer(address _lawyer) public onlyOwner{
        accessLevels[_lawyer] = AccessLevel.Lawyer;
        emit LawyerAdded(_lawyer);
    }

}
