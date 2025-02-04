import { Cl } from "@stacks/transactions";
import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;

describe("RLP Encoding Tests", () => {
  it("encodes cross chain message", () => {
    const sourceContract = simnet.callReadOnlyFn(
      "rlp-encode",
      "encode-string",
      [Cl.stringAscii("0x1.icon/cxc5d40fd74995bed473e5d1b259dbc6015273ffc5")],
      address1
    );

    const destAddress = simnet.callReadOnlyFn(
      "rlp-encode",
      "encode-string",
      [Cl.stringAscii("archway1rv84n8yczcug4rpwx028tkvwm5gerluzs28uhn")],
      address1
    );

    const sn = simnet.callReadOnlyFn(
      "rlp-encode",
      "encode-uint",
      [Cl.uint(11580)],
      address1
    );

    const msgType = simnet.callReadOnlyFn(
      "rlp-encode",
      "encode-uint",
      [Cl.uint(0)],
      address1
    );

    const emptyData = simnet.callReadOnlyFn(
      "rlp-encode",
      "encode-string",
      [Cl.stringAscii("")],
      address1
    );

    const destList = simnet.callReadOnlyFn(
      "rlp-encode",
      "encode-arr",
      [Cl.list([
        Cl.buffer(simnet.callReadOnlyFn(
          "rlp-encode",
          "encode-string",
          [Cl.stringAscii("archway1lvmx2u6f47n8yr0dg7fangur2l72nwxxklasqyal2fhtpyw9uxfqmudel8")],
          address1
          // @ts-ignore
        ).result.buffer)
      ])],
      address1
    );

    const innerMessage = simnet.callReadOnlyFn(
      "rlp-encode",
      "encode-arr",
      [Cl.list([
        // @ts-ignore
        Cl.buffer(sourceContract.result.buffer),
        // @ts-ignore
        Cl.buffer(destAddress.result.buffer),
        // @ts-ignore
        Cl.buffer(sn.result.buffer),
        // @ts-ignore
        Cl.buffer(msgType.result.buffer),
        // @ts-ignore
        Cl.buffer(emptyData.result.buffer),
        // @ts-ignore
        Cl.buffer(destList.result.buffer)
      ])],
      address1
    );

    const result = simnet.callReadOnlyFn(
      "rlp-encode",
      "encode-arr",
      [Cl.list([
        Cl.buffer(simnet.callReadOnlyFn(
          "rlp-encode",
          "encode-uint",
          [Cl.uint(1)],
          address1
        // @ts-ignore
        ).result.buffer),
        // @ts-ignore
        Cl.buffer(innerMessage.result.buffer)
      ])],
      address1
    );

    // @ts-ignore
    expect(result.result.buffer).toEqual(
      Cl.bufferFromHex("f8b301b8b0f8aeb33078312e69636f6e2f637863356434306664373439393562656434373365356431623235396462633630313532373366666335ae6172636877617931727638346e3879637a6375673472707778303238746b76776d356765726c757a73323875686e822d3c0080f844b84261726368776179316c766d783275366634376e3879723064673766616e677572326c37326e7778786b6c61737179616c3266687470797739757866716d7564656c38").buffer
    );
  });
});

it("decodes cross chain message", () => {
  const encodedMessage = "f8b301b8b0f8aeb33078312e69636f6e2f637863356434306664373439393562656434373365356431623235396462633630313532373366666335ae6172636877617931727638346e3879637a6375673472707778303238746b76776d356765726c757a73323875686e822d3c0080f844b84261726368776179316c766d783275366634376e3879723064673766616e677572326c37326e7778786b6c61737179616c3266687470797739757866716d7564656c38";

  console.log("Step 1: Initial encoded message");
  console.log("Encoded message:", encodedMessage);

  // First decode the outer array using rlp-to-list
  const decoded = simnet.callReadOnlyFn(
    "rlp-decode",
    "rlp-to-list",
    [Cl.bufferFromHex(encodedMessage)],
    address1
  );

  console.log("\nStep 2: First level decoding");
  console.log("Decoded result:", decoded.result);

  // Assert first level decoding produced a list with expected elements
  expect(decoded.result.type).toBe(11); // List type
  expect(decoded.result.list.length).toBe(2); // Should have 2 elements
  expect(decoded.result.list[0].type).toBe(2); // First element should be a buffer
  expect(decoded.result.list[1].type).toBe(2); // Second element should be a buffer

  // Extract and decode inner message
  const innerDecoded = simnet.callReadOnlyFn(
    "rlp-decode",
    "rlp-to-list",
    // @ts-ignore
    [decoded.result.list[1]],
    address1
  );

  console.log("\nStep 3: Inner message decoding");
  console.log("Inner decoded result:", innerDecoded.result);

  // Assert inner decoding produced expected structure
  expect(innerDecoded.result.type).toBe(11); // List type
  expect(innerDecoded.result.list.length).toBe(6); // Should have 6 elements

  // Print and verify each element
  console.log("\nStep 4: Decoding individual elements");

  // Source Contract
  console.log("4.1: Source Contract");
  const sourceContract = simnet.callReadOnlyFn(
    "rlp-decode",
    "rlp-decode-string",
    [
      Cl.list([innerDecoded.result.list[0]]),
      Cl.uint(0)
    ],
    address1
  );
  console.log("Source contract result:", sourceContract.result);
  expect(sourceContract.result).toEqual(
    Cl.some(Cl.stringAscii("0x1.icon/cxc5d40fd74995bed473e5d1b259dbc6015273ffc5"))
  );
  

  // Destination Address
  console.log("\n4.2: Destination Address");
  const destAddress = simnet.callReadOnlyFn(
    "rlp-decode",
    "rlp-decode-string",
    [
      Cl.list([innerDecoded.result.list[1]]),
      Cl.uint(0)
    ],
    address1
  );
  console.log("Destination address result:", destAddress.result);
  expect(destAddress.result).toEqual(
    Cl.some(Cl.stringAscii("archway1rv84n8yczcug4rpwx028tkvwm5gerluzs28uhn"))
  );

  // Sequence Number
  console.log("\n4.3: Sequence Number");
  const sn = simnet.callReadOnlyFn(
    "rlp-decode",
    "rlp-decode-uint",
    [
      Cl.list([innerDecoded.result.list[2]]),
      Cl.uint(0)
    ],
    address1
  );
  console.log("Sequence number result:", sn.result);
  expect(sn.result).toEqual(Cl.uint(11580));

  // Message Type
  console.log("\n4.4: Message Type");
  const msgType = simnet.callReadOnlyFn(
    "rlp-decode",
    "rlp-decode-uint",
    [
      Cl.list([innerDecoded.result.list[3]]),
      Cl.uint(0)
    ],
    address1
  );
  console.log("Message type result:", msgType.result);
  expect(msgType.result).toEqual(Cl.uint(0));

  // Empty Data
  console.log("\n4.5: Empty Data");
  const emptyData = simnet.callReadOnlyFn(
    "rlp-decode",
    "rlp-decode-string",
    [
      Cl.list([innerDecoded.result.list[4]]),
      Cl.uint(0)
    ],
    address1
  );
  console.log("Empty data buffer:", Buffer.from(innerDecoded.result.list[4].buffer).toString('hex'));
  console.log("Data result:", emptyData.result);
  expect(emptyData.result).toEqual(Cl.some(Cl.stringAscii("")));


  console.log("\n4.6: Destination List");
// Print the raw buffer before decoding
const destListBuffer = innerDecoded.result.list[5];
console.log("Destination list raw buffer:", 
    Buffer.from(destListBuffer.buffer).toString('hex')
);

const destListDecoded = simnet.callReadOnlyFn(
  "rlp-decode",
  "rlp-to-list",
  [innerDecoded.result.list[5]],
  address1
);
console.log("Destination list decoded:", destListDecoded.result);
console.log("Destination list decoded result list:", destListDecoded.result.list)

console.log("\nDebug events from decode-string:");
console.log(destListDecoded.events.map(event => event.data).join('\n'));

// Print the first item's buffer before string decoding
const firstItem = destListDecoded.result.list[0];
console.log("First destination buffer:", 
    Buffer.from(firstItem.buffer).toString('hex')
);

const destAddress1 = simnet.callReadOnlyFn(
  "rlp-decode",
  "rlp-decode-string",
  [
    Cl.list([destListDecoded.result.list[0]]),
    Cl.uint(0)
  ],
  address1
);

console.log("\nDebug events from string decoding:");
console.log(destAddress1.events.map(event => event.data).join('\n'));

  console.log("Destination address 1 result:", destAddress1.result);
  expect(destAddress1.result).toEqual(
    Cl.stringAscii("archway1lvmx2u6f47n8yr0dg7fangur2l72nwxxklasqyal2fhtpyw9uxfqmudel8")
  );

  console.log("\nStep 5: All elements decoded successfully");
});
