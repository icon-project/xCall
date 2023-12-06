// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;
pragma abicoder v2;

import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@xcall/utils/Types.sol";
import "@xcall/contracts/xcall/interfaces/IConnection.sol";
import "@iconfoundation/btp2-solidity-library/interfaces/ICallService.sol";
pragma solidity ^0.8.0;


contract CentralizedConnection is Initializable, IConnection {

    mapping(string => uint256) private messageFees;
    mapping(string => uint256) private responseFees;
    mapping(string => mapping(uint256 => uint256)) receipts;
    address private xCall;
    address private adminAddress;


    event Message(string targetNetwork,int256 sn,bytes _msg);


    modifier onlyAdmin() {
        require(msg.sender == this.admin(), "OnlyRelayer");
        _;
    }

    function initialize(address _relayer, address _xCall) public initializer {
        xCall = _xCall;
        adminAddress = _relayer;
    }

    /**
     @notice Sets the fee to the target network
     @param networkId String Network Id of target chain
     @param messageFee Integer ( The fee needed to send a Message )
     @param responseFee Integer (The fee of the response )
     */
    function setFee(
        string calldata networkId,
        uint256 messageFee,
        uint256 responseFee
    ) external onlyAdmin {
        messageFees[networkId] = messageFee;
        responseFees[networkId] = responseFee;
    }

    /**
     @notice Gets the fee to the target network
    @param to String Network Id of target chain
    @param response Boolean ( Whether the responding fee is included )
    @return fee Integer (The fee of sending a message to a given destination network )
    */
    function getFee(string memory to, bool response) external view override returns (uint256 fee) {
        uint256 messageFee = messageFees[to];
        if (response == true) {
            uint256 responseFee = responseFees[to];
            return messageFee + responseFee;
        }
        return messageFee;
    }

    /**
     @notice Sends the message to a specific network.
     @param sn : positive for two-way message, zero for one-way message, negative for response
     @param to  String ( Network Id of destination network )
     @param svc String ( name of the service )
     @param sn  Integer ( serial number of the message )
     @param _msg Bytes ( serialized bytes of Service Message )
     */
    function sendMessage(
        string calldata to,
        string calldata svc,
        int256 sn,
        bytes calldata _msg
    ) external override payable {
        require(msg.sender == xCall, "Only Xcall can call sendMessage");
        emit Message(to, sn, _msg);
    }

    /**
     @notice Sends the message to a xCall.
     @param srcNetwork  String ( Network Id )
     @param sn Integer ( serial number of the message )
     @param _msg Bytes ( serialized bytes of Service Message )
     */
    function recvMessage(
        string memory srcNetwork,
        uint256 sn,
        bytes calldata _msg
    ) public onlyAdmin {
        require(receipts[srcNetwork][sn]==0,"Duplicate Message");
        receipts[srcNetwork][sn]=1;
        ICallService(xCall).handleMessage(srcNetwork, _msg);
    }

    /**
     @notice Sends the balance of the contract to the owner(relayer)

    */
    function claimFees() public onlyAdmin {
        payable(adminAddress).transfer(address(this).balance);
    }

    /**
     @notice Revert a messages, used in special cases where message can't just be dropped
     @param sn  Integer ( serial number of the message )
     */
    function revertMessage(uint256 sn) public onlyAdmin {
        ICallService(xCall).handleError(sn);
    }

    /**
     @notice Gets a message receipt
     @param srcNetwork String ( Network Id )
     @param sn Integer ( serial number of the message )
     @return boolean if is has been recived or not
     */
    function getReceipt(string memory srcNetwork, uint256 sn) public view returns (uint256) {
        return receipts[srcNetwork][sn];
    }

    /**
        @notice Set the address of the admin.
        @param _address The address of the admin.
     */
    function setAdmin(address _address) external onlyAdmin {
        adminAddress = _address;
    }

    /**
       @notice Gets the address of admin
       @return (Address) the address of admin
    */
    function admin(
    ) external view returns (
        address
    ) {
        return adminAddress;
    }


}