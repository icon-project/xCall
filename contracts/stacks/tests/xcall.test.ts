import { beforeEach, describe, expect, it } from "vitest";
import { encode } from "rlp";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer");

const XCALL_IMPL_CONTRACT_NAME = "xcall-impl";
const XCALL_PROXY_CONTRACT_NAME = "xcall-proxy";
const CENTRALIZED_CONNECTION_CONTRACT_NAME = "centralized-connection";
const MOCK_DAPP_CONTRACT_NAME = "mock-dapp";

const STACKS_NID = "stacks";
const ICON_NID = "test";

const sourceContract = accounts.get("wallet_1")!;
const destinationContract = deployer! + "." + MOCK_DAPP_CONTRACT_NAME;

const from = `${STACKS_NID}/${sourceContract}`;
const to = `${ICON_NID}/${destinationContract}`;

const CS_MESSAGE_TYPE_REQUEST = 1;
const CS_MESSAGE_TYPE_RESULT = 2;
const CS_MESSAGE_RESULT_SUCCESS = 1;
const CS_MESSAGE_RESULT_FAILURE = 0;

const xcallImpl = Cl.contractPrincipal(deployer!, XCALL_IMPL_CONTRACT_NAME);
const xcallProxy = Cl.contractPrincipal(deployer!, XCALL_PROXY_CONTRACT_NAME);
const centralizedConnection = Cl.contractPrincipal(
  deployer!,
  CENTRALIZED_CONNECTION_CONTRACT_NAME
);
const mockDapp = Cl.contractPrincipal(deployer!, MOCK_DAPP_CONTRACT_NAME);

describe("xcall", () => {
  beforeEach(() => {
    simnet.callPublicFn(
      XCALL_IMPL_CONTRACT_NAME,
      "init",
      [
        Cl.stringAscii(STACKS_NID),
        Cl.stringAscii(deployer! + "." + XCALL_IMPL_CONTRACT_NAME),
      ],
      deployer!
    );

    const upgradeProxyResult = simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "upgrade",
      [xcallImpl, Cl.none()],
      deployer!
    );
    expect(upgradeProxyResult.result).toBeOk(Cl.bool(true));

    const setAdminResult = simnet.callPublicFn(
      XCALL_IMPL_CONTRACT_NAME,
      "set-admin",
      [Cl.principal(deployer!)],
      deployer!
    );
    expect(setAdminResult.result).toBeOk(Cl.bool(true));

    simnet.callPublicFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "initialize",
      [xcallProxy, Cl.principal(deployer!)],
      deployer!
    );

    simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "set-default-connection",
      [
        Cl.stringAscii(STACKS_NID),
        Cl.stringAscii(deployer! + "." + CENTRALIZED_CONNECTION_CONTRACT_NAME),
        xcallImpl,
      ],
      deployer!
    );

    simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "set-default-connection",
      [
        Cl.stringAscii(ICON_NID),
        Cl.stringAscii(deployer! + "." + CENTRALIZED_CONNECTION_CONTRACT_NAME),
        xcallImpl,
      ],
      deployer!
    );

    simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "set-protocol-fee-handler",
      [centralizedConnection, xcallImpl],
      deployer!
    );

    simnet.callPublicFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "set-fee",
      [Cl.stringAscii(STACKS_NID), Cl.uint(500000), Cl.uint(250000)],
      deployer!
    );

    simnet.callPublicFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "set-fee",
      [Cl.stringAscii(ICON_NID), Cl.uint(1000000), Cl.uint(500000)],
      deployer!
    );

    const protocolFee = 100000;
    simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "set-protocol-fee",
      [Cl.uint(protocolFee), xcallImpl],
      deployer!
    );

    simnet.callPublicFn(
      MOCK_DAPP_CONTRACT_NAME,
      "initialize",
      [xcallProxy],
      deployer!
    );

    simnet.callPublicFn(
      MOCK_DAPP_CONTRACT_NAME,
      "add-connection",
      [
        Cl.stringAscii(STACKS_NID),
        Cl.stringAscii(deployer! + "." + CENTRALIZED_CONNECTION_CONTRACT_NAME),
        Cl.stringAscii(deployer! + "." + CENTRALIZED_CONNECTION_CONTRACT_NAME),
      ],
      deployer!
    );

    simnet.callPublicFn(
      MOCK_DAPP_CONTRACT_NAME,
      "add-connection",
      [
        Cl.stringAscii(ICON_NID),
        Cl.stringAscii(deployer! + "." + CENTRALIZED_CONNECTION_CONTRACT_NAME),
        Cl.stringAscii(deployer! + "." + CENTRALIZED_CONNECTION_CONTRACT_NAME),
      ],
      deployer!
    );
  });

  it("verifies protocol sources and destinations are passed correctly in send-message", () => {
    const data = Uint8Array.from(encode(["Hello, Destination Contract!"]));
    const expectedSn = 1;

    const sourcesResult = simnet.callReadOnlyFn(
      MOCK_DAPP_CONTRACT_NAME,
      "get-sources",
      [Cl.stringAscii(ICON_NID)],
      deployer!
    );
    expect(sourcesResult.result).toStrictEqual(
      Cl.list([
        Cl.stringAscii(deployer! + "." + CENTRALIZED_CONNECTION_CONTRACT_NAME),
      ])
    );

    const destinationsResult = simnet.callReadOnlyFn(
      MOCK_DAPP_CONTRACT_NAME,
      "get-destinations",
      [Cl.stringAscii(ICON_NID)],
      deployer!
    );
    expect(destinationsResult.result).toStrictEqual(
      Cl.list([
        Cl.stringAscii(deployer! + "." + CENTRALIZED_CONNECTION_CONTRACT_NAME),
      ])
    );

    const sendMessageResult = simnet.callPublicFn(
      MOCK_DAPP_CONTRACT_NAME,
      "send-message",
      [Cl.stringAscii(to), Cl.buffer(data), Cl.none(), xcallImpl],
      sourceContract
    );
    expect(sendMessageResult.result).toBeOk(Cl.uint(expectedSn));

    const callMessageSentEvent = sendMessageResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'TrueCV'.
        e.data.value!.data.event.data === "CallMessageSent"
    );
    expect(callMessageSentEvent).toBeDefined();

    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'TrueCV'.
    const eventData = callMessageSentEvent!.data.value!.data;
    expect(eventData.from).toStrictEqual(Cl.principal(sourceContract));
    expect(eventData.to).toStrictEqual(Cl.stringAscii(to));
    expect(eventData.sn).toStrictEqual(Cl.uint(expectedSn));
  });

  it("verifies send-message with specific input data", () => {
    const to = "test/cxfa65fef6524222c5edad37989da26deaa5b4a40a";
    const svc = "";
    const sn = 3;
    const msgHex =
      "0x30783464363537333733363136373635353437323631366537333636363537323534363537333734363936653637353736393734363836663735373435323666366336633632363136333662";

    const msg = new Uint8Array(
      msgHex
        .slice(2) // Remove '0x' prefix
        .match(/.{1,2}/g)! // Split into pairs
        .map((byte) => parseInt(byte, 16)) // Convert each pair to number
    );

    const sendMessageResult = simnet.callPublicFn(
      "centralized-connection",
      "send-message",
      [Cl.stringAscii(to), Cl.stringAscii(svc), Cl.int(sn), Cl.buffer(msg)],
      deployer!
    );

    // Verify the transaction succeeded
    expect(sendMessageResult.result).toBeOk(Cl.int(1)); // Should return next conn-sn

    // Verify the Message event was emitted correctly
    const messageEvent = sendMessageResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
        e.data.value.data.event.data === "Message"
    );
    expect(messageEvent).toBeDefined();

    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
    const eventData = messageEvent!.data.value.data;

    // Verify event data matches input
    expect(eventData.to).toStrictEqual(Cl.stringAscii(to));
    expect(eventData.sn).toStrictEqual(Cl.int(1));
    expect(eventData.msg).toStrictEqual(Cl.buffer(msg));

    // Verify connection sequence number was incremented
    const getConnSnResult = simnet.callReadOnlyFn(
      "centralized-connection",
      "get-conn-sn",
      [],
      deployer!
    );
    expect(getConnSnResult.result).toBeOk(Cl.int(1));
  });

  it("verifies the connection is properly initialized", () => {
    const xcallResult = simnet.callReadOnlyFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "get-xcall",
      [],
      deployer!
    );
    expect(xcallResult.result).toBeOk(Cl.some(xcallProxy));

    const adminResult = simnet.callReadOnlyFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "get-admin",
      [],
      deployer!
    );
    expect(adminResult.result).toBeOk(Cl.principal(deployer!));

    const stacksFeeResult = simnet.callReadOnlyFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "get-fee",
      [Cl.stringAscii(STACKS_NID), Cl.bool(true)],
      deployer!
    );
    expect(stacksFeeResult.result).toBeOk(Cl.uint(750000)); // 500000 base fee + 250000 rollback fee

    const iconFeeResult = simnet.callReadOnlyFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "get-fee",
      [Cl.stringAscii(ICON_NID), Cl.bool(true)],
      deployer!
    );
    expect(iconFeeResult.result).toBeOk(Cl.uint(1500000)); // 1000000 base fee + 500000 rollback fee

    const dappResult = simnet.callReadOnlyFn(
      MOCK_DAPP_CONTRACT_NAME,
      "get-sources",
      [Cl.stringAscii(STACKS_NID)],
      deployer!
    );
    expect(dappResult.result).toStrictEqual(
      Cl.list([
        Cl.stringAscii(deployer! + "." + CENTRALIZED_CONNECTION_CONTRACT_NAME),
      ])
    );
  });

  it("verifies the current implementation after upgrade is xcallImpl", () => {
    const getCurrentImplementationResult = simnet.callReadOnlyFn(
      XCALL_PROXY_CONTRACT_NAME,
      "get-current-implementation",
      [],
      deployer!
    );

    expect(getCurrentImplementationResult.result).toBeOk(xcallImpl);

    const isCurrentImplementationResult = simnet.callReadOnlyFn(
      XCALL_PROXY_CONTRACT_NAME,
      "is-current-implementation",
      [xcallImpl],
      deployer!
    );

    expect(isCurrentImplementationResult.result).toBeOk(Cl.bool(true));

    const isNotCurrentImplementationResult = simnet.callReadOnlyFn(
      XCALL_PROXY_CONTRACT_NAME,
      "is-current-implementation",
      [Cl.contractPrincipal(deployer!, CENTRALIZED_CONNECTION_CONTRACT_NAME)],
      deployer!
    );

    expect(isNotCurrentImplementationResult.result).toBeOk(Cl.bool(false));
  });

  it("sends and executes a call", () => {
    const data = Uint8Array.from(encode(["Hello, Destination Contract!"]));
    const expectedSn = 1;
    const expectedReqId = 1;

    const sendCallResult = simnet.callPublicFn(
      xcallProxy.contractName.content,
      "send-call",
      [Cl.stringAscii(to), Cl.buffer(data), xcallImpl],
      sourceContract
    );

    console.log("Send call events:", sendCallResult.events);

    expect(sendCallResult.result).toBeOk(Cl.uint(expectedSn));
    const callMessageSentEvent = sendCallResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e?.data.value?.data.event.data === "CallMessageSent"
    );

    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    expect(callMessageSentEvent?.data.value!.data.event.data).toBe(
      "CallMessageSent"
    );
    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    expect(callMessageSentEvent?.data.value!.data.from).toStrictEqual(
      Cl.principal(sourceContract)
    );
    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    expect(callMessageSentEvent?.data.value!.data.to).toStrictEqual(
      Cl.stringAscii(to)
    );
    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    expect(callMessageSentEvent?.data.value!.data.sn).toStrictEqual(Cl.uint(1));

    const messageData = encode([from, to, expectedSn, expectedReqId, data, []]);

    const csMessageRequest = encode([CS_MESSAGE_TYPE_REQUEST, messageData]);
    console.log("CS Message Request hex:", csMessageRequest.toString('hex'));

    const recvMessageResult = simnet.callPublicFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "recv-message",
      [
        Cl.stringAscii(STACKS_NID),
        Cl.int(expectedSn),
        Cl.buffer(csMessageRequest),
        xcallImpl,
      ],
      deployer!
    );

    console.log("Recv message events:", recvMessageResult.events);
console.log("CS Message Request:", csMessageRequest);

    expect(recvMessageResult.result).toBeOk(Cl.bool(true));

    const callMessageEvent = recvMessageResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e.data.value!.data.event.data === "CallMessage"
    );
    expect(callMessageEvent).toBeDefined();
    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    const callMessageData = callMessageEvent!.data.value!.data;
    expect(callMessageData.from.data).toBe(from);
    expect(callMessageData.to.data).toBe(to);
    const reqId = callMessageData["req-id"].value;
    expect(Number(callMessageData.sn.value)).toBe(expectedSn);
    expect(Number(callMessageData["req-id"].value)).toBe(expectedReqId);

    const slicedData = data.slice(1); // rlp decode drops length byte
    const executeCallResult = simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "execute-call",
      [Cl.uint(reqId), Cl.buffer(slicedData), mockDapp, xcallImpl, xcallImpl],
      deployer!
    );
    expect(executeCallResult.result).toBeOk(Cl.bool(true));

    const callExecutedEvent = executeCallResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e.data.value!.data.event.data === "CallExecuted"
    );
    expect(callExecutedEvent).toBeDefined();
    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    const callExecutedData = callExecutedEvent!.data.value!.data;
    expect(Number(callExecutedData.code.value)).toBe(CS_MESSAGE_RESULT_SUCCESS);
    expect(Number(callExecutedData["req-id"].value)).toBe(expectedReqId);
    expect(callExecutedData.msg.data).toBe("");

    const messageReceivedEvent = executeCallResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e.data.value!.data.event.data === "MessageReceived"
    );
    expect(messageReceivedEvent).toBeDefined();
    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    const messageReceivedData = messageReceivedEvent!.data.value!.data;
    expect(messageReceivedData.data).toStrictEqual(
      Cl.stringAscii("Hello, Destination Contract!")
    );
    expect(messageReceivedData.from).toStrictEqual(Cl.stringAscii(from));

    const responseData = encode([expectedSn, CS_MESSAGE_RESULT_SUCCESS]);

    const csMessageResponse = encode([CS_MESSAGE_TYPE_RESULT, responseData]);

    const handleResponseResult = simnet.callPublicFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "recv-message",
      [
        Cl.stringAscii(ICON_NID),
        Cl.int(-expectedSn),
        Cl.buffer(csMessageResponse),
        xcallImpl,
      ],
      deployer!
    );

    expect(handleResponseResult.result).toBeErr(Cl.uint(203)); // message not found because ack is only sent on rollback

    const verifySuccessResult = simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "verify-success",
      [Cl.uint(1), xcallImpl],
      sourceContract
    );
    expect(verifySuccessResult.result).toBeOk(Cl.bool(false));
  });

  it("sends a message with rollback and executes rollback on failure", () => {
    const expectedSn = 1;
    const expectedReqId = 1;
    const data = Uint8Array.from(encode(["Hello, Destination Contract!"]));
    const rollbackData = Uint8Array.from(encode(["Rollback data"])).slice(1);

    const sendCallResult = simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "send-call-message",
      [
        Cl.stringAscii(to),
        Cl.buffer(data),
        Cl.some(Cl.buffer(rollbackData)),
        Cl.none(),
        Cl.none(),
        xcallImpl,
      ],
      deployer!
    );
    expect(sendCallResult.result).toBeOk(Cl.uint(expectedSn));

    const messageData = encode([from, to, expectedSn, expectedReqId, data, []]);

    const csMessageRequest = encode([CS_MESSAGE_TYPE_REQUEST, messageData]);

    const recvMessageResult = simnet.callPublicFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "recv-message",
      [
        Cl.stringAscii(STACKS_NID),
        Cl.int(expectedSn),
        Cl.buffer(csMessageRequest),
        xcallImpl,
      ],
      deployer!
    );

    expect(recvMessageResult.result).toBeOk(Cl.bool(true));

    const callMessageEvent = recvMessageResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e.data.value!.data.event.data === "CallMessage"
    );
    expect(callMessageEvent).toBeDefined();

    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    const callMessageData = callMessageEvent!.data.value!.data;
    const reqId = callMessageData["req-id"].value;
    expect(callMessageData.from.data).toBe(from);
    expect(callMessageData.to.data).toBe(to);
    expect(Number(callMessageData.sn.value)).toBe(expectedSn);
    expect(Number(reqId)).toBe(expectedReqId);

    const slicedData = data.slice(1); // rlp decode drops length byte
    const executeCallResult = simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "execute-call",
      [Cl.uint(reqId), Cl.buffer(slicedData), mockDapp, xcallImpl, xcallImpl],
      deployer!
    );
    expect(executeCallResult.result).toBeOk(Cl.bool(true));

    const callExecutedEvent = executeCallResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e.data.value!.data.event.data === "CallExecuted"
    );
    expect(callExecutedEvent).toBeDefined();
    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    const callExecutedData = callExecutedEvent!.data.value!.data;
    expect(Number(callExecutedData.code.value)).toBe(CS_MESSAGE_RESULT_SUCCESS);
    expect(Number(callExecutedData["req-id"].value)).toBe(expectedReqId);
    expect(callExecutedData.msg.data).toBe("");

    const messageReceivedEvent = executeCallResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e.data.value!.data.event.data === "MessageReceived"
    );
    expect(messageReceivedEvent).toBeDefined();
    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    const messageReceivedData = messageReceivedEvent!.data.value!.data;
    expect(messageReceivedData.data).toStrictEqual(
      Cl.stringAscii("Hello, Destination Contract!")
    );
    expect(messageReceivedData.from).toStrictEqual(Cl.stringAscii(from));

    const failureResponseData = encode([expectedSn, CS_MESSAGE_RESULT_FAILURE]);
    const csMessageResponse = encode([
      CS_MESSAGE_TYPE_RESULT,
      failureResponseData,
    ]);

    const handleFailureResult = simnet.callPublicFn(
      CENTRALIZED_CONNECTION_CONTRACT_NAME,
      "recv-message",
      [
        Cl.stringAscii(ICON_NID),
        Cl.int(-expectedSn),
        Cl.buffer(csMessageResponse),
        xcallImpl,
      ],
      deployer!
    );
    expect(handleFailureResult.result).toBeOk(Cl.bool(true));

    const responseMessageEvent = handleFailureResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e.data.value!.data.event.data === "ResponseMessage"
    );
    expect(responseMessageEvent).toBeDefined();
    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    expect(responseMessageEvent!.data.value!.data.code).toStrictEqual(
      Cl.uint(CS_MESSAGE_RESULT_FAILURE)
    );

    const rollbackMessageEvent = handleFailureResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e.data.value!.data.event.data === "RollbackMessage"
    );
    expect(rollbackMessageEvent).toBeDefined();

    const executeRollbackResult = simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "execute-rollback",
      [Cl.uint(expectedSn), mockDapp, xcallImpl, xcallImpl],
      deployer!
    );
    expect(executeRollbackResult.result).toBeOk(Cl.bool(true));

    const rollbackExecutedEvent = executeRollbackResult.events.find(
      (e) =>
        e.event === "print_event" &&
        // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
        e.data.value!.data.event.data === "RollbackReceived"
    );
    expect(rollbackExecutedEvent).toBeDefined();

    // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'. Property 'data' does not exist on type 'ContractPrincipalCV'.
    const rollbackExecutedData = rollbackExecutedEvent!.data.value!.data;
    expect(rollbackExecutedData.from).toStrictEqual(
      Cl.stringAscii(
        STACKS_NID + "/" + deployer! + "." + XCALL_IMPL_CONTRACT_NAME
      )
    );
    expect(rollbackExecutedData.data).toStrictEqual(
      Cl.stringAscii("Rollback data")
    );

    const getOutgoingMessage = simnet.callReadOnlyFn(
      XCALL_IMPL_CONTRACT_NAME,
      "get-outgoing-message",
      [Cl.uint(expectedSn)],
      deployer!
    );
    expect(getOutgoingMessage.result).toBeNone();
  });

  // it("handles execute-call failure correctly", () => {
  //   const data = Uint8Array.from(encode(["rollback"]));
  //   const expectedSn = 1;
  //   const expectedReqId = 1;
  //   const rollbackData = Uint8Array.from(encode(["Rollback Message"])).slice(1);

  //   const sendCallResult = simnet.callPublicFn(
  //     XCALL_PROXY_CONTRACT_NAME,
  //     "send-call-message",
  //     [
  //       Cl.stringAscii(to),
  //       Cl.buffer(data),
  //       Cl.some(Cl.buffer(rollbackData)),
  //       Cl.none(),
  //       Cl.none(),
  //       xcallImpl,
  //     ],
  //     deployer!
  //   );
  //   expect(sendCallResult.result).toBeOk(Cl.uint(expectedSn));

  //   const messageData = encode([from, to, expectedSn, expectedReqId, data, []]);

  //   const csMessageRequest = encode([CS_MESSAGE_TYPE_REQUEST, messageData]);

  //   const recvMessageResult = simnet.callPublicFn(
  //     CENTRALIZED_CONNECTION_CONTRACT_NAME,
  //     "recv-message",
  //     [
  //       Cl.stringAscii(STACKS_NID),
  //       Cl.int(expectedSn),
  //       Cl.buffer(csMessageRequest),
  //       xcallImpl,
  //     ],
  //     deployer!
  //   );
  //   expect(recvMessageResult.result).toBeOk(Cl.bool(true));

  //   const callMessageEvent = recvMessageResult.events.find(
  //     (e) =>
  //       e.event === "print_event" &&
  //       // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
  //       e.data.value!.data.event.data === "CallMessage"
  //   );
  //   expect(callMessageEvent).toBeDefined();
  //   // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
  //   const reqId = callMessageEvent!.data.value!.data["req-id"].value;

  //   const slicedData = data.slice(1);
  //   const executeCallResult = simnet.callPublicFn(
  //     XCALL_PROXY_CONTRACT_NAME,
  //     "execute-call",
  //     [Cl.uint(reqId), Cl.buffer(slicedData), mockDapp, xcallImpl, xcallImpl],
  //     deployer!
  //   );
  //   expect(executeCallResult.result).toBeErr(Cl.uint(802)); // ERR_INVALID_MESSAGE

  //   // Verify CallExecuted event shows failure
  //   const callExecutedEvent = executeCallResult.events.find(
  //     (e) =>
  //       e.event === "print_event" &&
  //       // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
  //       e.data.value!.data.event.data === "CallExecuted"
  //   );
  //   expect(callExecutedEvent).toBeDefined();
  //   // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
  //   const callExecutedData = callExecutedEvent!.data.value!.data;
  //   expect(Number(callExecutedData.code.value)).toBe(CS_MESSAGE_RESULT_FAILURE);
  //   expect(Number(callExecutedData["req-id"].value)).toBe(expectedReqId);

  //   // Verify ResponseMessage event
  //   const responseMessageEvent = executeCallResult.events.find(
  //     (e) =>
  //       e.event === "print_event" &&
  //       // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
  //       e.data.value!.data.event.data === "ResponseMessage"
  //   );
  //   expect(responseMessageEvent).toBeDefined();
  //   // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
  //   expect(responseMessageEvent!.data.value!.data.code).toStrictEqual(
  //     Cl.uint(CS_MESSAGE_RESULT_FAILURE)
  //   );

  //   // Verify RollbackMessage event is emitted
  //   const rollbackMessageEvent = executeCallResult.events.find(
  //     (e) =>
  //       e.event === "print_event" &&
  //       // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
  //       e.data.value!.data.event.data === "RollbackMessage"
  //   );
  //   expect(rollbackMessageEvent).toBeDefined();

  //   // Execute rollback
  //   const executeRollbackResult = simnet.callPublicFn(
  //     XCALL_PROXY_CONTRACT_NAME,
  //     "execute-rollback",
  //     [Cl.uint(expectedSn), mockDapp, xcallImpl, xcallImpl],
  //     deployer!
  //   );
  //   expect(executeRollbackResult.result).toBeOk(Cl.bool(true));

  //   // Verify RollbackExecuted event
  //   const rollbackExecutedEvent = executeRollbackResult.events.find(
  //     (e) =>
  //       e.event === "print_event" &&
  //       // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
  //       e.data.value!.data.event.data === "RollbackReceived"
  //   );
  //   expect(rollbackExecutedEvent).toBeDefined();
  //   // @ts-ignore: Property 'data' does not exist on type 'ClarityValue'
  //   const rollbackExecutedData = rollbackExecutedEvent!.data.value!.data;
  //   expect(rollbackExecutedData.from).toStrictEqual(
  //     Cl.stringAscii(
  //       STACKS_NID + "/" + deployer! + "." + XCALL_IMPL_CONTRACT_NAME
  //     )
  //   );
  //   expect(rollbackExecutedData.data).toStrictEqual(
  //     Cl.stringAscii("Rollback Message")
  //   );
  // });

  it("calculates fees correctly for different scenarios", () => {
    const feeStacksNoRollback = simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "get-fee",
      [Cl.stringAscii(STACKS_NID), Cl.bool(false), Cl.none(), xcallImpl],
      sourceContract
    );
    expect(feeStacksNoRollback.result).toBeOk(Cl.uint(600000)); // 500000 base fee + 100000 protocol fee

    const feeStacksWithRollback = simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "get-fee",
      [Cl.stringAscii(STACKS_NID), Cl.bool(true), Cl.none(), xcallImpl],
      sourceContract
    );
    expect(feeStacksWithRollback.result).toBeOk(Cl.uint(850000)); // 500000 base fee + 250000 rollback fee + 100000 protocol fee

    const feeIconWithRollback = simnet.callPublicFn(
      XCALL_PROXY_CONTRACT_NAME,
      "get-fee",
      [Cl.stringAscii(ICON_NID), Cl.bool(true), Cl.none(), xcallImpl],
      sourceContract
    );
    expect(feeIconWithRollback.result).toBeOk(Cl.uint(1600000)); // 1000000 base fee + 500000 rollback fee + 100000 protocol fee
  });

  it("parses cs-message correctly", () => {
    const sn = 1;
    const messageType = 1;
    const data = Buffer.from("Hello, ICON!");
    const protocols = ["protocol1", "protocol2"];

    const messageData = encode([from, to, sn, messageType, data, protocols]);

    const parseCSMessageRequestResult = simnet.callPublicFn(
      XCALL_IMPL_CONTRACT_NAME,
      "parse-cs-message-request",
      [Cl.buffer(messageData)],
      deployer!
    );

    console.log("Message data:", messageData);
console.log("Parse CS message events:", parseCSMessageRequestResult.events);


    // @ts-ignore: Property 'value' does not exist on type 'ClarityValue'. Property 'value' does not exist on type 'ContractPrincipalCV'.
    const parsedResult = parseCSMessageRequestResult.result.value.data;
    expect(parsedResult.from).toStrictEqual(Cl.stringAscii(from));
    expect(parsedResult.to).toStrictEqual(Cl.stringAscii(to));
    expect(parsedResult.sn).toStrictEqual(Cl.uint(sn));
    expect(parsedResult.type).toStrictEqual(Cl.uint(messageType));
    expect(parsedResult.protocols).toStrictEqual(
      Cl.list(protocols.map((p) => Cl.stringAscii(p)))
    );

    const csMessage = encode([CS_MESSAGE_TYPE_REQUEST, messageData]);

    const parseCSMessageResult = simnet.callPrivateFn(
      XCALL_IMPL_CONTRACT_NAME,
      "parse-cs-message",
      [Cl.buffer(csMessage)],
      deployer!
    );

    expect(parseCSMessageResult.result).toBeOk(
      Cl.tuple({
        type: Cl.uint(1),
        data: Cl.buffer(messageData),
      })
    );

    const parseCSMessageRequestResult2 = simnet.callPublicFn(
      XCALL_IMPL_CONTRACT_NAME,
      "parse-cs-message-request",
      // @ts-ignore: Property 'value' does not exist on type 'ClarityValue'. Property 'value' does not exist on type 'ContractPrincipalCV'.
      [parseCSMessageResult.result.value.data.data],
      deployer!
    );

    // @ts-ignore: Property 'value' does not exist on type 'ClarityValue'. Property 'value' does not exist on type 'ContractPrincipalCV'.
    const parsedResult2 = parseCSMessageRequestResult2.result.value.data;
    expect(parsedResult2.from).toStrictEqual(Cl.stringAscii(from));
    expect(parsedResult2.to).toStrictEqual(Cl.stringAscii(to));
    expect(parsedResult2.sn).toStrictEqual(Cl.uint(sn));
    expect(parsedResult2.type).toStrictEqual(Cl.uint(messageType));
    expect(parsedResult2.protocols).toStrictEqual(
      Cl.list(protocols.map((p) => Cl.stringAscii(p)))
    );
  });
});
