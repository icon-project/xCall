use core::panic;

use soroban_sdk::{token, Address, Bytes, BytesN, Env, FromVal, Map, String, Vec};
use ed25519_dalek::{PublicKey, Signature, Verifier};
use crate::{errors::ContractError, interfaces::interface_xcall::XcallClient, storage};

pub fn ensure_admin(e: &Env) -> Result<Address, ContractError> {
    let admin = storage::admin(&e)?;
    admin.require_auth();

    Ok(admin)
}

pub fn ensure_upgrade_authority(e: &Env) -> Result<Address, ContractError> {
    let authority = storage::get_upgrade_authority(&e)?;
    authority.require_auth();

    Ok(authority)
}

pub fn ensure_xcall(e: &Env) -> Result<Address, ContractError> {
    let xcall = storage::get_xcall(&e)?;
    xcall.require_auth();

    Ok(xcall)
}

pub fn get_network_fee(
    env: &Env,
    network_id: String,
    response: bool,
) -> Result<u128, ContractError> {
    let mut fee = storage::get_msg_fee(&env, network_id.clone())?;
    if response {
        fee += storage::get_res_fee(&env, network_id)?;
    }

    Ok(fee)
}

pub fn transfer_token(
    e: &Env,
    from: &Address,
    to: &Address,
    amount: &u128,
) -> Result<(), ContractError> {
    let native_token = storage::native_token(&e)?;
    let client = token::Client::new(&e, &native_token);

    client.transfer(&from, &to, &(*amount as i128));
    Ok(())
}

pub fn verify_signatures(
    e: &Env,
    signatures: Vec<BytesN<64>>,
    message: Bytes,
) -> bool {
    let validators = storage::get_validators(e).unwrap();
    let threshold = storage::get_validators_threshold(e).unwrap();

    if signatures.len() < threshold {
        return false
    }
    let message_hash = e.crypto().sha256(&message);
     let mut unique_validators = Map::new(e);
     let mut count = 0;
     

      for signature in signatures.iter() {
        if let Ok(sig) = convert_signature_to_dalek(&signature) {
            for validator in validators.iter() {
                if let Ok(public_key) = convert_address_to_public_key(e, &validator) {
                    if public_key.verify(&message_hash.to_array(), &sig).is_ok() {
                        if !unique_validators.contains_key(validator.clone()) {
                            unique_validators.set(validator, count);
                            count += 1;
                        }
                        break;
                    }
                }
            }
        }
    }
    (unique_validators.len() as u32) >= threshold

}
 

pub fn call_xcall_handle_message(e: &Env, nid: &String, msg: Bytes) -> Result<(), ContractError> {
    let xcall_addr = storage::get_xcall(&e)?;
    let client = XcallClient::new(&e, &xcall_addr);
    client.handle_message(&e.current_contract_address(), nid, &msg);

    Ok(())
}

pub fn call_xcall_handle_error(e: &Env, sn: u128) -> Result<(), ContractError> {
    let xcall_addr = storage::get_xcall(&e)?;
    let client = XcallClient::new(&e, &xcall_addr);
    client.handle_error(&e.current_contract_address(), &sn);

    Ok(())
}

fn convert_address_to_public_key(e: &Env, address: &Address) -> Result<PublicKey, ed25519_dalek::SignatureError> {
    let bytes: BytesN<32> = BytesN::from_val(e, &address.to_val());
    PublicKey::from_bytes(&bytes.to_array())
}

// Helper function to convert a BytesN<64> to ed25519_dalek::Signature
fn convert_signature_to_dalek(signature: &BytesN<64>) -> Result<Signature, ed25519_dalek::SignatureError> {
    Signature::from_bytes(&signature.to_array())
}