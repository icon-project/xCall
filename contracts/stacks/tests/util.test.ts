import { describe, it, expect } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer");

describe("util", () => {
  it("converts address string to principal correctly", () => {
    const address = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM" + "." + "centralized-connection";
    
    const result = simnet.callPublicFn(
      "util",
      "address-string-to-principal",
      [Cl.stringAscii(address)],
      deployer!
    );

    // Check if the result is successful
    expect(result.result).toBeOk(
      Cl.contractPrincipal(
        "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
        "centralized-connection"
      )
    );
  });
});