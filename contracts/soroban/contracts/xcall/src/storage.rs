use soroban_sdk::{Address, BytesN, Env, String, Vec};
use soroban_xcall_lib::network_address::NetworkAddress;

use crate::{
    errors::ContractError,
    types::{
        request::CSMessageRequest,
        rollback::Rollback,
        storage_types::{Config, StorageKey},
    },
};

pub const MAX_ROLLBACK_SIZE: u64 = 1024;
pub const MAX_DATA_SIZE: u64 = 2048;

pub fn is_initialized(e: &Env) -> Result<(), ContractError> {
    let initialized = e.storage().instance().has(&StorageKey::Admin);
    if initialized {
        Err(ContractError::AlreadyInitialized)
    } else {
        Ok(())
    }
}

pub fn admin(e: &Env) -> Result<Address, ContractError> {
    e.storage()
        .instance()
        .get(&StorageKey::Admin)
        .ok_or(ContractError::Uninitialized)
}

pub fn get_config(e: &Env) -> Result<Config, ContractError> {
    e.storage()
        .instance()
        .get(&StorageKey::Config)
        .ok_or(ContractError::Uninitialized)
}

pub fn get_fee_handler(e: &Env) -> Result<Address, ContractError> {
    e.storage()
        .instance()
        .get(&StorageKey::FeeHandler)
        .ok_or(ContractError::Uninitialized)
}

pub fn protocol_fee(e: &Env) -> u128 {
    e.storage()
        .instance()
        .get(&StorageKey::ProtocolFee)
        .unwrap_or(0)
}

pub fn default_connection(e: &Env, nid: String) -> Result<Address, ContractError> {
    e.storage()
        .instance()
        .get(&StorageKey::DefaultConnections(nid))
        .ok_or(ContractError::NoDefaultConnection)
}

pub fn get_rollback(e: &Env, sequence_no: u128) -> Result<Rollback, ContractError> {
    e.storage()
        .instance()
        .get(&StorageKey::Rollback(sequence_no))
        .ok_or(ContractError::CallRequestNotFound)
}

pub fn get_successful_response(e: &Env, sn: u128) -> bool {
    e.storage()
        .instance()
        .get(&StorageKey::SuccessfulResponses(sn))
        .unwrap_or(false)
}

pub fn get_next_sn(e: &Env) -> u128 {
    let mut sn: u128 = e.storage().instance().get(&StorageKey::Sn).unwrap_or(0);
    sn += 1;
    e.storage().instance().set(&StorageKey::Sn, &sn);

    sn
}

pub fn get_proxy_request(e: &Env, req_id: u128) -> Result<CSMessageRequest, ContractError> {
    e.storage()
        .instance()
        .get(&StorageKey::ProxyRequest(req_id))
        .ok_or(ContractError::InvalidRequestId)
}

pub fn get_reply_state(e: &Env) -> Option<CSMessageRequest> {
    e.storage().instance().get(&StorageKey::ReplyState)
}

pub fn get_pending_request(e: &Env, hash: BytesN<32>) -> Vec<String> {
    e.storage()
        .instance()
        .get(&StorageKey::PendingRequests(hash))
        .unwrap_or(Vec::new(&e))
}

pub fn get_pending_response(e: &Env, hash: BytesN<32>) -> Vec<String> {
    e.storage()
        .instance()
        .get(&StorageKey::PendingResponses(hash))
        .unwrap_or(Vec::new(&e))
}

pub fn get_call_reply(e: &Env) -> Option<CSMessageRequest> {
    e.storage()
        .instance()
        .get(&StorageKey::CallReply)
        .unwrap_or(None)
}

pub fn get_own_network_address(e: &Env) -> Result<NetworkAddress, ContractError> {
    let config = get_config(&e)?;
    let from = NetworkAddress::new(
        &e,
        config.network_id,
        e.current_contract_address().to_string(),
    );

    Ok(from)
}

pub fn store_admin(e: &Env, address: &Address) {
    e.storage().instance().set(&StorageKey::Admin, &address);
}

pub fn store_config(e: &Env, config: Config) {
    e.storage().instance().set(&StorageKey::Config, &config)
}

pub fn store_fee_handler(e: &Env, address: &Address) {
    e.storage()
        .instance()
        .set(&StorageKey::FeeHandler, &address);
}

pub fn store_protocol_fee(e: &Env, fee: u128) {
    e.storage().instance().set(&StorageKey::ProtocolFee, &fee)
}

pub fn store_default_connection(e: &Env, nid: String, address: &Address) {
    e.storage()
        .instance()
        .set(&StorageKey::DefaultConnections(nid), &address);
}

pub fn store_rollback(e: &Env, sn: u128, rollback: &Rollback) {
    e.storage()
        .instance()
        .set(&StorageKey::Rollback(sn), rollback)
}

pub fn remove_rollback(e: &Env, sn: u128) {
    e.storage().instance().remove(&StorageKey::Rollback(sn))
}

pub fn store_proxy_request(e: &Env, req_id: u128, request: &CSMessageRequest) {
    e.storage()
        .instance()
        .set(&StorageKey::ProxyRequest(req_id), request)
}

pub fn remove_proxy_request(e: &Env, req_id: u128) {
    e.storage()
        .instance()
        .remove(&StorageKey::ProxyRequest(req_id))
}

pub fn store_call_reply(e: &Env, reply: &CSMessageRequest) {
    e.storage().instance().set(&StorageKey::CallReply, reply)
}

pub fn remove_call_reply(e: &Env) -> Option<CSMessageRequest> {
    let call_reply = get_call_reply(&e);
    e.storage().instance().remove(&StorageKey::CallReply);
    call_reply
}

pub fn store_reply_state(e: &Env, req: &CSMessageRequest) {
    e.storage().instance().set(&StorageKey::ReplyState, req)
}

pub fn remove_reply_state(e: &Env) {
    e.storage().instance().remove(&StorageKey::ReplyState)
}

pub fn store_pending_request(e: &Env, hash: BytesN<32>, sources: &Vec<String>) {
    e.storage()
        .instance()
        .set(&StorageKey::PendingRequests(hash), sources);
}

pub fn remove_pending_request(e: &Env, hash: BytesN<32>) {
    e.storage()
        .instance()
        .remove(&StorageKey::PendingRequests(hash))
}

pub fn store_pending_response(e: &Env, hash: BytesN<32>, sources: &Vec<String>) {
    e.storage()
        .instance()
        .set(&StorageKey::PendingResponses(hash), sources)
}

pub fn remove_pending_response(e: &Env, hash: BytesN<32>) {
    e.storage()
        .instance()
        .remove(&StorageKey::PendingResponses(hash))
}

pub fn increment_last_request_id(e: &Env) -> u128 {
    e.storage()
        .instance()
        .update(&StorageKey::LastReqId, |value| -> u128 {
            if let Some(req_id) = value {
                return req_id + 1;
            }
            1
        })
}

pub fn save_success_response(e: &Env, sn: u128) {
    e.storage()
        .instance()
        .set(&StorageKey::SuccessfulResponses(sn), &true)
}
