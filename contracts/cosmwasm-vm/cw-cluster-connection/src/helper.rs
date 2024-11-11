use std::collections::HashMap;

use cosmwasm_std::{ensure_eq, Addr, BalanceResponse, BankQuery, Coin};
use cw_xcall_lib::network_address::NetId;
use k256::ecdsa::VerifyingKey;

use super::*;

pub fn sha256(data: &[u8]) -> Vec<u8> {
    use sha2::Digest;
    sha2::Sha256::digest(data).to_vec()
}

pub fn keccak256(input: &[u8]) -> [u8; 32] {
    use sha3::{Digest, Keccak256};
    let mut hasher = Keccak256::new();
    hasher.update(input);
    let out: [u8; 32] = hasher.finalize().to_vec().try_into().unwrap();
    out
}

pub fn to_truncated_le_bytes(n: u128) -> Vec<u8> {
    let bytes = n.to_le_bytes();
    let trimmed_bytes = bytes
        .iter()
        .rev()
        .skip_while(|&&b| b == 0)
        .copied()
        .collect::<Vec<u8>>();
    trimmed_bytes.into_iter().rev().collect()
}

impl<'a> ClusterConnection<'a> {
    pub fn ensure_admin(&self, store: &dyn Storage, address: Addr) -> Result<(), ContractError> {
        let admin = self.get_admin(store)?;
        ensure_eq!(admin, address, ContractError::OnlyAdmin);

        Ok(())
    }

    pub fn ensure_relayer(&self, store: &dyn Storage, address: Addr) -> Result<(), ContractError> {
        let relayer = self.get_relayer(store)?;
        ensure_eq!(relayer, address, ContractError::OnlyRelayer);

        Ok(())
    }

    pub fn ensure_xcall(&self, store: &dyn Storage, address: Addr) -> Result<(), ContractError> {
        let xcall = self.get_xcall(store)?;
        ensure_eq!(xcall, address, ContractError::OnlyXCall);

        Ok(())
    }

    pub fn get_amount_for_denom(&self, funds: &Vec<Coin>, target_denom: String) -> u128 {
        for coin in funds.iter() {
            if coin.denom == target_denom {
                return coin.amount.into();
            }
        }
        0
    }

    pub fn get_balance(&self, deps: &DepsMut, env: Env, denom: String) -> u128 {
        let address = env.contract.address.to_string();
        let balance_query = BankQuery::Balance { denom, address };
        let balance_response: BalanceResponse = deps.querier.query(&balance_query.into()).unwrap();

        balance_response.amount.amount.u128()
    }

    pub fn hex_encode(&self, data: Vec<u8>) -> String {
        if data.is_empty() {
            "null".to_string()
        } else {
            hex::encode(data)
        }
    }

    pub fn hex_decode(&self, val: String) -> Result<Vec<u8>, ContractError> {
        let hex_string_trimmed = val.trim_start_matches("0x");
        hex::decode(hex_string_trimmed)
            .map_err(|e| ContractError::InvalidHexData { msg: e.to_string() })
    }

    pub fn call_xcall_handle_message(
        &self,
        store: &dyn Storage,
        nid: &NetId,
        msg: Vec<u8>,
    ) -> Result<SubMsg, ContractError> {
        let xcall_host = self.get_xcall(store)?;
        let xcall_msg = cw_xcall_lib::xcall_msg::ExecuteMsg::HandleMessage {
            from_nid: nid.clone(),
            msg,
        };
        let call_message: CosmosMsg<Empty> = CosmosMsg::Wasm(WasmMsg::Execute {
            contract_addr: xcall_host.to_string(),
            msg: to_json_binary(&xcall_msg).unwrap(),
            funds: vec![],
        });
        let sub_msg: SubMsg = SubMsg::new(call_message);
        Ok(sub_msg)
    }

    pub fn verify_signatures(
        &self,
        deps: Deps,
        threshold: u8,
        signed_msg: Vec<u8>,
        signatures: Vec<Vec<u8>>,
    ) -> Result<(), ContractError> {
        if signatures.len() < threshold.into() {
            return Err(ContractError::InsufficientSignatures);
        }

        let message_hash = keccak256(&signed_msg);

        let mut signers: HashMap<Vec<u8>, bool> = HashMap::new();

        for signature in signatures {
            if signature.len() != 65 {
                return Err(ContractError::InvalidSignature);
            }
            let mut recovery_code = signature[0];
            if recovery_code >= 27 {
                recovery_code = recovery_code - 27;
            }
            match deps
                .api
                .secp256k1_recover_pubkey(&message_hash, &signature[1..65], recovery_code)
            {
                Ok(pubkey) => {
                    let pk = VerifyingKey::from_sec1_bytes(&pubkey)
                        .map_err(|_| ContractError::InvalidSignature)?;
                    let pk_vec = pk.to_bytes().to_vec();

                    if self.is_validator(deps.storage, pk_vec.clone())
                        && !signers.contains_key(&pk_vec)
                    {
                        signers.insert(pk_vec, true);
                        if signers.len() >= threshold.into() {
                            return Ok(());
                        }
                    }
                }
                Err(e) => {
                    continue;
                }
            }
        }

        Err(ContractError::InsufficientSignatures)
    }
}
