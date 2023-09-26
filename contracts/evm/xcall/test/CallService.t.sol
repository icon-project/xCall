// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/CallService.sol";

import "@iconfoundation/btp2-solidity-library/utils/NetworkAddress.sol";
import "@iconfoundation/btp2-solidity-library/utils/ParseAddress.sol";
import "@iconfoundation/btp2-solidity-library/utils/Integers.sol";
import "@iconfoundation/btp2-solidity-library/utils/Strings.sol";

import "@iconfoundation/btp2-solidity-library/contracts/interfaces/IConnection.sol";
import "@iconfoundation/btp2-solidity-library/contracts/interfaces/ICallServiceReceiver.sol";
import "@iconfoundation/btp2-solidity-library/contracts/interfaces/IDefaultCallServiceReceiver.sol";
import "@iconfoundation/btp2-solidity-library/contracts/interfaces/ICallService.sol";

import "../contracts/test/DAppProxySample.sol";



contract CallServiceTest is Test {
    CallService public callService;
    DAppProxySample public dapp;

    IConnection public baseConnection;
    IConnection public connection1;
    IConnection public connection2;

    ICallServiceReceiver public receiver;
    IDefaultCallServiceReceiver public defaultServiceReceiver;

    IConnection public connection1;
    IConnection public connection2;
    
    ICallServiceReceiver public receiver;
    IDefaultCallServiceReceiver public defaultServiceReceiver;

    ICallServiceReceiver public receiver;
    IDefaultCallServiceReceiver public defaultServiceReceiver;

    address public owner = address(0x1111);
    address public user = address(0x1234);

    address public xcall;
    string public iconNid = "0x2.ICON";
    string public ethNid = "0x1.ETH";
    string public iconDapp = NetworkAddress.networkAddress(iconNid, "0xa");

    string public netTo;
    string public dstAccount;
    string public ethDappAddress;

    string public baseIconConnection = "0xb";

    string[] _baseSource;
    string[] _baseDestination;

    string constant xcallMulti = "xcall-multi";

    event CallMessage(
        string indexed _from,
        string indexed _to,
        uint256 indexed _sn,
        uint256 _reqId,
        bytes _data
    );

    event CallExecuted(
        uint256 indexed _reqId,
        int _code,
        string _msg
    );

    event CallMessageSent(
        address indexed _from,
        string indexed _to,
        uint256 indexed _sn
    );

    event ResponseMessage(
        uint256 indexed _sn,
        int _code
    );

    event RollbackMessage(
        uint256 indexed _sn
    );

    event RollbackExecuted(
        uint256 indexed _sn
    );

    function setUp() public {
        dapp = new DAppProxySample();
        ethDappAddress = NetworkAddress.networkAddress(ethNid, ParseAddress.toString(address(dapp)));
        (netTo, dstAccount) = NetworkAddress.parseNetworkAddress(iconDapp);

        baseConnection = IConnection(address(0x01));

        _baseSource = new string[](1);
        _baseSource[0] = ParseAddress.toString(address(baseConnection));
        _baseDestination = new string[](1);
        _baseDestination[0] = baseIconConnection;
        vm.mockCall(address(baseConnection), abi.encodeWithSelector(baseConnection.getFee.selector), abi.encode(0));

        callService = new CallService();
        callService.initialize(ethNid);

    }

    function testSetAdmin() public {
        callService.setAdmin(user);
        assertEq(callService.admin(), user);
    }

    function testSetAdminUnauthorized() public {
        vm.prank(user);
        vm.expectRevert("OnlyAdmin");
        callService.setAdmin(user);
    }

    function testSetProtocolFees() public {
        callService.setProtocolFee(10);
        assertEq(callService.getProtocolFee(), 10);
    }

    function testSetProtocolFeesAdmin() public {
        callService.setAdmin(user);
        vm.prank(user);
        callService.setProtocolFee(10);

        assertEq(callService.getProtocolFee(), 10);
    }

    function testSetProtocolFeesUnauthorized() public {
        vm.prank(user);
        vm.expectRevert("OnlyAdmin");
        callService.setProtocolFee(10);
    }

    function testSetProtocolFeeFeeHandler() public {
        callService.setProtocolFeeHandler(user);
        assertEq(callService.getProtocolFeeHandler(), user);
    }

    function testSetProtocolFeeHandlerUnauthorized() public {
        vm.prank(user);
        vm.expectRevert("OnlyAdmin");
        callService.setProtocolFeeHandler(user);
    }

    function testHandleResponseDefaultProtocol() public {
        bytes memory data = bytes("test");

        callService.setDefaultConnection(iconNid, address(baseConnection));

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(dapp)), 1, false, data, new string[](0));
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.expectEmit();
        emit CallMessage(iconDapp, ParseAddress.toString(address(dapp)), 1, 1, data);

        vm.prank(address(baseConnection));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testHandleResponseDefaultProtocolInvalidSender() public {
        bytes memory data = bytes("test");

        callService.setDefaultConnection(iconNid, address(baseConnection));
        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(dapp)), 1, false, data, new string[](0));
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.prank(address(user));
        vm.expectRevert("NotAuthorized");
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testHandleResponseSingleProtocol() public {
        bytes memory data = bytes("test");

        string[] memory sources = new string[](1);
        sources[0] = ParseAddress.toString(address(baseConnection));

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(dapp)), 1, false, data, sources);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));
        vm.prank(address(baseConnection));

        vm.expectEmit();
        emit CallMessage(iconDapp, ParseAddress.toString(address(dapp)), 1, 1, data);

        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testHandleResponseSingleProtocolInvalidSender() public {
        bytes memory data = bytes("test");

        string[] memory sources = new string[](1);
        sources[0] = ParseAddress.toString(address(baseConnection));

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(dapp)), 1, false, data, sources);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.prank(address(connection1));
        vm.expectRevert("NotAuthorized");

        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testHandleResponseMultiProtocol() public {
        bytes memory data = bytes("test");

        connection1 = IConnection(address(0x0000000000000000000000000000000000000011));
        connection2 = IConnection(address(0x0000000000000000000000000000000000000012));

        vm.mockCall(address(connection1), abi.encodeWithSelector(connection1.getFee.selector), abi.encode(0));
        vm.mockCall(address(connection2), abi.encodeWithSelector(connection2.getFee.selector), abi.encode(0));

        string[] memory connections = new string[](2);
        connections[0] = ParseAddress.toString(address(connection1));
        connections[1] = ParseAddress.toString(address(connection2));

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(dapp)), 1, false, data, connections);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.prank(address(connection1));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        vm.expectEmit();
        emit CallMessage(iconDapp, ParseAddress.toString(address(dapp)), 1, 1, data);
        vm.prank(address(connection2));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testExecuteCallSingleProtocol() public {
        bytes memory data = bytes("test");

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(receiver)), 1, false, data, _baseSource);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.prank(address(baseConnection));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        vm.expectEmit();
        emit CallExecuted(1, 1, "");

        vm.prank(user);
        vm.mockCall(address(receiver), abi.encodeWithSelector(receiver.handleCallMessage.selector, iconDapp, data, _baseSource), abi.encode(1));
        callService.executeCall(1, data);

    }

    function testExecuteCallDefaultProtocol() public {
        bytes memory data = bytes("test");

        defaultServiceReceiver = IDefaultCallServiceReceiver(address(0x5678));
        callService.setDefaultConnection(netTo, address(baseConnection));

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(defaultServiceReceiver)), 1, false, data, _baseSource);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.prank(address(baseConnection));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        vm.expectEmit();
        emit CallExecuted(1, 1, "");

        vm.prank(user);
        vm.mockCall(address(defaultServiceReceiver), abi.encodeWithSelector(defaultServiceReceiver.handleCallMessage.selector, iconDapp, data), abi.encode(1));
        callService.executeCall(1, data);
    }

    function testExecuteCallMultiProtocol() public {
        bytes memory data = bytes("test");

        defaultServiceReceiver = IDefaultCallServiceReceiver(address(0x5678));
        connection1 = IConnection(address(0x0000000000000000000000000000000000000011));
        connection2 = IConnection(address(0x0000000000000000000000000000000000000012));

        string[] memory connections = new string[](2);
        connections[0] = ParseAddress.toString(address(connection1));
        connections[1] = ParseAddress.toString(address(connection2));

        vm.mockCall(address(connection1), abi.encodeWithSelector(connection1.getFee.selector), abi.encode(0));
        vm.mockCall(address(connection2), abi.encodeWithSelector(connection2.getFee.selector), abi.encode(0));

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(receiver)), 1, false, data, connections);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.prank(address(connection1));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        vm.prank(address(connection2));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        vm.expectEmit();
        emit CallExecuted(1, 1, "");

        vm.prank(user);
        vm.mockCall(address(receiver), abi.encodeWithSelector(receiver.handleCallMessage.selector, iconDapp, data, connections), abi.encode(1));
        callService.executeCall(1, data);
    }

    function testRollBackSingleProtocol() public {
        bytes memory data = bytes("test");
        bytes memory rollbackData = bytes("rollback");

        vm.prank(address(dapp));
        vm.expectEmit();
        emit CallMessageSent(address(dapp), iconDapp, 1);

        uint256 sn = callService.sendCallMessage{value: 0 ether}(iconDapp, data, rollbackData, _baseSource, _baseDestination);
        assertEq(sn, 1);

        Types.CSMessageResponse memory response = Types.CSMessageResponse(1, Types.CS_RESP_FAILURE);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(response));

        vm.expectEmit();
        emit ResponseMessage(1, Types.CS_RESP_FAILURE);
        emit RollbackMessage(1);

        vm.prank(address(baseConnection));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testRollBackDefaultProtocol() public {
        bytes memory data = bytes("test");
        bytes memory rollbackData = bytes("rollback");

        callService.setDefaultConnection(netTo, address(baseConnection));

        vm.prank(address(dapp));
        vm.expectEmit();
        emit CallMessageSent(address(dapp), iconDapp, 1);

        uint256 sn = callService.sendCallMessage{value: 0 ether}(iconDapp, data, rollbackData, _baseSource, _baseDestination);
        assertEq(sn, 1);

        Types.CSMessageResponse memory response = Types.CSMessageResponse(1, Types.CS_RESP_FAILURE);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(response));

        vm.expectEmit();
        emit ResponseMessage(1, Types.CS_RESP_FAILURE);

        vm.prank(address(baseConnection));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testRollBackDefaultProtocolInvalidSender() public {
        bytes memory data = bytes("test");
        bytes memory rollbackData = bytes("rollback");

        callService.setDefaultConnection(netTo, address(baseConnection));

        vm.prank(address(dapp));
        vm.expectEmit();
        emit CallMessageSent(address(dapp), iconDapp, 1);

        uint256 sn = callService.sendCallMessage{value: 0 ether}(iconDapp, data, rollbackData, _baseSource, _baseDestination);
        assertEq(sn, 1);

        Types.CSMessageResponse memory response = Types.CSMessageResponse(1, Types.CS_RESP_FAILURE);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(response));

        vm.prank(address(user));
        vm.expectRevert("NotAuthorized");
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testRollbackMultiProtocol() public {
        bytes memory data = bytes("test");
        bytes memory rollbackData = bytes("rollback");

        connection1 = IConnection(address(0x0000000000000000000000000000000000000011));
        connection2 = IConnection(address(0x0000000000000000000000000000000000000012));

        vm.mockCall(address(connection1), abi.encodeWithSelector(connection1.getFee.selector), abi.encode(0));
        vm.mockCall(address(connection2), abi.encodeWithSelector(connection2.getFee.selector), abi.encode(0));

        string[] memory connections = new string[](2);
        connections[0] = ParseAddress.toString(address(connection1));
        connections[1] = ParseAddress.toString(address(connection2));

        string[] memory destinations = new string[](2);
        destinations[0] = "0x1icon";
        destinations[1] = "0x2icon";

        vm.prank(address(dapp));
        vm.expectEmit();
        emit CallMessageSent(address(dapp), iconDapp, 1);

        uint256 sn = callService.sendCallMessage{value: 0 ether}(iconDapp, data, rollbackData, connections, destinations);
        assertEq(sn, 1);

        Types.CSMessageResponse memory response = Types.CSMessageResponse(1, Types.CS_RESP_FAILURE);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(response));

        vm.prank(address(connection1));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        vm.expectEmit();
        emit ResponseMessage(1, Types.CS_RESP_FAILURE);

        vm.prank(address(connection2));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testRollBackSuccess() public {
        bytes memory data = bytes("test");
        bytes memory rollbackData = bytes("rollback");

        vm.prank(address(dapp));
        vm.expectEmit();
        emit CallMessageSent(address(dapp), iconDapp, 1);

        uint256 sn = callService.sendCallMessage{value: 0 ether}(iconDapp, data, rollbackData, _baseSource, _baseDestination);
        assertEq(sn, 1);

        Types.CSMessageResponse memory response = Types.CSMessageResponse(1, Types.CS_RESP_SUCCESS);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(response));

        vm.expectEmit();
        emit ResponseMessage(1, Types.CS_RESP_SUCCESS);

        vm.prank(address(baseConnection));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));
    }

    function testExecuteRollBackDefaultProtocol() public {
       bytes memory data = bytes("test");
       bytes memory rollbackData = bytes("rollback");

       defaultServiceReceiver = IDefaultCallServiceReceiver(address(0x5678));
       string memory xcallAddr = NetworkAddress.networkAddress(ethNid, ParseAddress.toString(address(callService)));

       callService.setDefaultConnection(iconNid, address(baseConnection));

       vm.startPrank(address(defaultServiceReceiver));

       string[] memory connections = new string[](1);
       connections[0] = "";


       uint256 sn = callService.sendCallMessage{value: 0 ether}(iconDapp, data, rollbackData);
       assertEq(sn, 1);
       vm.stopPrank();

       Types.CSMessageResponse memory msgRes = Types.CSMessageResponse(1, Types.CS_RESP_FAILURE);
       Types.CSMessage memory msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(msgRes));

       vm.prank(address(baseConnection));
       callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

       vm.expectEmit();
       emit RollbackExecuted(1);
       
       vm.mockCall(address(callService), abi.encodeWithSelector(defaultServiceReceiver.handleCallMessage.selector, xcallAddr, rollbackData), abi.encode(1));
       vm.prank(user);
       callService.executeRollback(1);
   }


   function testExecuteRollBackSingleProtocol() public {
       bytes memory data = bytes("test");
       bytes memory rollbackData = bytes("rollback");

       string memory xcallAddr = NetworkAddress.networkAddress(ethNid, ParseAddress.toString(address(callService)));

       vm.prank(address(dapp));
       vm.expectEmit();
       emit CallMessageSent(address(dapp), iconDapp, 1);

       uint256 sn = callService.sendCallMessage{value: 0 ether}(iconDapp, data, rollbackData, _baseSource, _baseDestination);
       assertEq(sn, 1);

       Types.CSMessageResponse memory msgRes = Types.CSMessageResponse(1, Types.CS_RESP_FAILURE);
       Types.CSMessage memory msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(msgRes));

       vm.prank(address(baseConnection));
       callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

       vm.expectEmit();
       emit RollbackExecuted(1);

       vm.mockCall(address(dapp), abi.encodeWithSelector(receiver.handleCallMessage.selector, xcallAddr, rollbackData, _baseSource), abi.encode(1));
       vm.prank(user);
       callService.executeRollback(1);
   }

    function testExecuteRollbackMultiProtocol() public {
         bytes memory data = bytes("test");
         bytes memory rollbackData = bytes("rollback");

         string memory xcallAddr = NetworkAddress.networkAddress(ethNid, ParseAddress.toString(address(callService)));

         connection1 = IConnection(address(0x0000000000000000000000000000000000000011));
         connection2 = IConnection(address(0x0000000000000000000000000000000000000012));

         vm.mockCall(address(connection1), abi.encodeWithSelector(connection1.getFee.selector), abi.encode(0));
         vm.mockCall(address(connection2), abi.encodeWithSelector(connection2.getFee.selector), abi.encode(0));

         string[] memory connections = new string[](2);
         connections[0] = ParseAddress.toString(address(connection1));
         connections[1] = ParseAddress.toString(address(connection2));

         string[] memory destinations = new string[](2);
         destinations[0] = "0x1icon";
         destinations[1] = "0x2icon";

         vm.prank(address(dapp));
         vm.expectEmit();
         emit CallMessageSent(address(dapp), iconDapp, 1);

         uint256 sn = callService.sendCallMessage{value: 0 ether}(iconDapp, data, rollbackData, connections, destinations);
         assertEq(sn, 1);

         Types.CSMessageResponse memory response = Types.CSMessageResponse(1, Types.CS_RESP_FAILURE);
         Types.CSMessage memory msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(response));

         vm.prank(address(connection1));
         callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

         vm.expectEmit();
         emit ResponseMessage(1, Types.CS_RESP_FAILURE);
         emit RollbackMessage(1);

         vm.prank(address(connection2));
         callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

         vm.prank(user);
         vm.mockCall(address(dapp), abi.encodeWithSelector(receiver.handleCallMessage.selector, xcallAddr, rollbackData, _baseSource), abi.encode(1));
         callService.executeRollback(sn);
     }
     
    function testExecuteCallMultiProtocolRollback() public {
        bytes memory data = bytes("test");

        defaultServiceReceiver = IDefaultCallServiceReceiver(address(0x5678));
        connection1 = IConnection(address(0x0000000000000000000000000000000000000011));
        connection2 = IConnection(address(0x0000000000000000000000000000000000000012));

        string[] memory connections = new string[](2);
        connections[0] = ParseAddress.toString(address(connection1));
        connections[1] = ParseAddress.toString(address(connection2));

        vm.mockCall(address(connection1), abi.encodeWithSelector(connection1.getFee.selector), abi.encode(0));
        vm.mockCall(address(connection2), abi.encodeWithSelector(connection2.getFee.selector), abi.encode(0));

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(receiver)), 1, true, data, connections);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.prank(address(connection1));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        vm.prank(address(connection2));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        vm.expectEmit();
        emit CallExecuted(1, 1, "");

        vm.prank(user);
        vm.mockCall(address(receiver), abi.encodeWithSelector(receiver.handleCallMessage.selector, iconDapp, data, connections), abi.encode(1));

        Types.CSMessageResponse memory msgResponse = Types.CSMessageResponse(1, Types.CS_RESP_SUCCESS);
        msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(msgResponse));

        vm.mockCall(address(connection1), abi.encodeWithSelector(connection1.sendMessage.selector, iconNid, xcallMulti, - 1, msg), abi.encode(1));
        vm.mockCall(address(connection2), abi.encodeWithSelector(connection2.sendMessage.selector, iconNid, xcallMulti, - 1, msg), abi.encode(1));

        callService.executeCall(1, data);
    }

    function testExecuteCallDefaultProtocolRollback() public {
        bytes memory data = bytes("test");

        defaultServiceReceiver = IDefaultCallServiceReceiver(address(0x5678));
        callService.setDefaultConnection(netTo, address(baseConnection));

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(defaultServiceReceiver)), 1, true, data, _baseSource);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.prank(address(baseConnection));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        vm.expectEmit();
        emit CallExecuted(1, 1, "");

        vm.prank(user);
        vm.mockCall(address(defaultServiceReceiver), abi.encodeWithSelector(defaultServiceReceiver.handleCallMessage.selector, iconDapp, data), abi.encode(0));

        Types.CSMessageResponse memory msgResponse = Types.CSMessageResponse(1, Types.CS_RESP_SUCCESS);
        msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(msgResponse));
        vm.mockCall(address(baseConnection), 0 ether , abi.encodeWithSelector(baseConnection.sendMessage.selector, iconNid, xcallMulti, -1, msg), abi.encode(1));

        callService.executeCall(1, data);
    }


    function testExecuteCallFailedExecution() public {
         bytes memory data = bytes("test");

        Types.CSMessageRequest memory request = Types.CSMessageRequest(iconDapp, ParseAddress.toString(address(receiver)), 1, true, data, _baseSource);
        Types.CSMessage memory msg = Types.CSMessage(Types.CS_REQUEST, RLPEncodeStruct.encodeCSMessageRequest(request));

        vm.prank(address(baseConnection));
        vm.mockCallRevert(address(baseConnection), abi.encodeWithSelector(receiver.handleCallMessage.selector, iconDapp, data, _baseSource), bytes("UserRevert"));
        callService.handleMessage(iconNid, RLPEncodeStruct.encodeCSMessage(msg));

        Types.CSMessageResponse memory msgResponse = Types.CSMessageResponse(1, Types.CS_RESP_FAILURE);
        msg = Types.CSMessage(Types.CS_RESPONSE, RLPEncodeStruct.encodeCSMessageResponse(msgResponse));

        vm.mockCall(address(receiver), 0 ether , abi.encodeWithSelector(baseConnection.sendMessage.selector, iconNid, xcallMulti, -1, msg), abi.encode(1));

        vm.expectEmit();
        emit CallExecuted(1, 0, "unknownError");
        callService.executeCall(1, data);
    }

}
