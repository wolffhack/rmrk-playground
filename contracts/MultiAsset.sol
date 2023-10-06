// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.21;
import "@rmrk-team/evm-contracts/contracts/implementations/premint/RMRKMultiAssetPreMint.sol";
// import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import {ChainlinkClient, Chainlink, LinkTokenInterface} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
// import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./RotamAccess.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";

    // ChainlinkClient,
    // ConfirmedOwner,
contract rotam is 
    RMRKMultiAssetPreMint
    AxelarExecutable
{
    // Variables

    //Axelar
    IAxelarGasService public immutable gasService;
    RotamAccess private rotamAccess;

    // ChainLink
    using Chainlink for Chainlink.Request;
    bytes32 private jobId;
    uint256 private fee;

    //Autoken 
    string public vinProcessing = "";
    string[] public vinCreated;

    struct Car {
        string brand;
        string model;
        string vin;
        string color_code;
        string date_of_manufacture;
        string warranty_expiration_date;
        string fuel_type;
        uint mileage;
        string[] repair_history;
        string[] maintenance_history;
        string last_update;
        bool hasFines;
    }
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => Car) private _cars;
    mapping(string => uint256) private _vinToTokenId;
    mapping(string => bool) private _isVinUsed;
    mapping(uint256 => bool) private _isTokenIdUsed;
    string public message;

    //Axelar CrossChain Moonbase Alpha gateway 0x5769D84DD62a6fD969856c75c7D321b84d455929

    //Axelar CrossChain Filecoin gas Service Contract 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6
    address gasServiceMoonbase = 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6;


    // Constructor
    constructor(
          address _rotamAccessAddress
          string memory collectionMetadata,
          uint256 maxSupply,
          address royaltyRecipient,
          uint16 royaltyPercentageBps
      )
          RMRKMultiAssetPreMint(
              "rotam",
              "RTM",
              collectionMetadata,
              maxSupply,
              royaltyRecipient,
              royaltyPercentageBps
            )
            ConfirmedOwner(msg.sender)
            AxelarExecutable(0x5769D84DD62a6fD969856c75c7D321b84d455929)
      {
        rotamAccess = RotamAccess(_rotamAccessAddress);
        //Axelar CrossChain
        gasService = IAxelarGasService(gasServiceMoonbase);
        //Chainlink Request
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0x40193c8518BB267228Fc409a613bDbD8eC5a97b3);
        jobId = "7d80a6386ef543a3abb52817f6707e3b";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
      }

    // Modifiers

    modifier onlyLawyer() {
        require(
            rotamAccess.accessLevels(msg.sender) ==
                RotamAccess.AccessLevel.Taller,
            "Only authorized Workshop"
    );
        _;
    }

    modifier onlyMechanic() {
        require(
            rotamAccess.accessLevels(msg.sender) ==
                RotamAccess.AccessLevel.Sucursal,
            "Only authorized Manufacturer"
        );
        _;
    }
      
    // Methods
     function createAutoken(
        address to,
        string memory brand,
        string memory model,
        string memory vin,
        string memory color_code,
        string memory date_of_manufacture,
        string memory warranty_expiration_date,
        string memory fuel_type,
        string memory last_update,
        string memory uriIpfsUrl
    ) public onlySucursal {
        require(_isVinUsed[vin] == false, "Car with this VIN already exists");
        uint256 tokenId = _tokenIdCounter.current() + 1;
        require(
            _isTokenIdUsed[tokenId] == false,
            "Car with this tokenId already exists"
        );
        _cars[tokenId] = Car(
            brand,
            model,
            vin,
            color_code,
            date_of_manufacture,
            warranty_expiration_date,
            fuel_type,
            0,
            new string[](0),
            new string[](0),
            last_update,
            false
        );
        _vinToTokenId[vin] = tokenId;
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uriIpfsUrl);
        _isVinUsed[vin] = true;
        vinCreated.push(vin);
        _isTokenIdUsed[tokenId] = true;
    }

    function updateAutoken(
        string memory vin,
        uint mileage,
        string memory newRepair,
        string memory newMaintenance,
        string memory newURI,
        string memory last_update
    ) public onlyTaller {
        require(_isVinUsed[vin] == true, "Car with this VIN does not exist");
        uint256 tokenId = _vinToTokenId[vin];
        Car storage carObject = _cars[tokenId];
        require(
            carObject.mileage < mileage,
            "New mileage value must be greater than the current value"
        );
        carObject.mileage = mileage;
        if (
            bytes(newRepair).length > 0 &&
            keccak256(bytes(newRepair)) != keccak256(bytes("undefined"))
        ) {
            carObject.repair_history.push(newRepair);
        }
        if (
            bytes(newMaintenance).length > 0 &&
            keccak256(bytes(newMaintenance)) != keccak256(bytes("undefined"))
        ) {
            carObject.maintenance_history.push(newMaintenance);
        }
        _setTokenURI(tokenId, newURI);
        carObject.last_update = last_update;
    }

    function sendMessage(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata _message
    ) external payable {
        bytes memory payload = abi.encode(_message);
        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            msg.sender
        );

        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata _payload
    ) internal override {
        message = abi.decode(_payload, (string));
    }

    function requestFinesApi(string memory vin) public {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillMultipleParameters.selector
        );
        vinProcessing = vin;
        string memory apiUrl = string(
            abi.encodePacked("https://fines-api.onrender.com/cars/fines/", vin)
        );
        req.add("get", apiUrl);
        req.add("path", "hasFines");
        sendChainlinkRequest(req, fee);
    }

    function fulfillMultipleParameters(
        bytes32 requestId,
        string memory hasFinesResponse
    ) public recordChainlinkFulfillment(requestId) {
        uint256 tokenId = _vinToTokenId[vinProcessing];
        Car storage carObject = _cars[tokenId];
        for (; keccak256(bytes(vinProcessing)) != keccak256(bytes("")); ) {
            if (
                keccak256(bytes(hasFinesResponse)) == keccak256(bytes("true"))
            ) {
                carObject.hasFines = true;
                vinProcessing = "";
            }
            if (
                keccak256(bytes(hasFinesResponse)) == keccak256(bytes("false"))
            ) {
                carObject.hasFines = false;
                vinProcessing = "";
            }
        }
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function checkFines(string memory vin) public {
        require(_isVinUsed[vin] == true, "Car with this VIN does not exist");
        requestFinesApi(vin);
    }

    function checkMessage() public view returns (string memory) {
        return message;
    }

    function checkFinesAndReturnCar(
        string memory vin
    ) public returns (Car memory objCar) {
        require(_isVinUsed[vin] == true, "Car with this VIN does not exist");
        requestFinesApi(vin);
        uint256 tokenId = _vinToTokenId[vin];
        Car storage carObject = _cars[tokenId];
        objCar = Car(
            carObject.brand,
            carObject.model,
            carObject.vin,
            carObject.color_code,
            carObject.date_of_manufacture,
            carObject.warranty_expiration_date,
            carObject.fuel_type,
            carObject.mileage,
            carObject.repair_history,
            carObject.maintenance_history,
            carObject.last_update,
            carObject.hasFines
        );
    }

    function getObjCarByVIN(
        string memory vin
    )
        public
        view
        returns (uint256 tokenId, Car memory objCar, string memory uri)
    {
        require(_isVinUsed[vin] == true, "Car with this VIN does not exist");
        tokenId = _vinToTokenId[vin];
        Car storage carObject = _cars[tokenId];
        objCar = Car(
            carObject.brand,
            carObject.model,
            carObject.vin,
            carObject.color_code,
            carObject.date_of_manufacture,
            carObject.warranty_expiration_date,
            carObject.fuel_type,
            carObject.mileage,
            carObject.repair_history,
            carObject.maintenance_history,
            carObject.last_update,
            carObject.hasFines
        );
        uri = super.tokenURI(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}
  