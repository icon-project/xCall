use anchor_lang::prelude::*;

pub mod constants;
pub mod error;
pub mod event;
pub mod helper;
pub mod instructions;
pub mod state;
pub mod types;

use instructions::*;

use xcall_lib::network_address::NetworkAddress;

declare_id!("DoSLJH36FLrQVjZ8wDD4tHHfLbisj4VwMzpvTV9yyyp2");

#[program]
pub mod xcall {
    use super::*;

    pub fn initialize(ctx: Context<ConfigCtx>, network_id: String) -> Result<()> {
        instructions::initialize(ctx, network_id)
    }

    pub fn set_admin(ctx: Context<SetAdminCtx>, account: Pubkey) -> Result<()> {
        instructions::set_admin(ctx, account)
    }

    pub fn set_protocol_fee(ctx: Context<SetFeeCtx>, fee: u64) -> Result<()> {
        instructions::set_protocol_fee(ctx, fee)
    }

    pub fn set_protocol_fee_handler(
        ctx: Context<SetFeeHandlerCtx>,
        fee_handler: Pubkey,
    ) -> Result<()> {
        instructions::set_protocol_fee_handler(ctx, fee_handler)
    }

    #[allow(unused_variables)]
    pub fn set_default_connection(
        ctx: Context<DefaultConnectionCtx>,
        network_id: String,
        connection: Pubkey,
    ) -> Result<()> {
        instructions::set_default_connection(ctx, connection)
    }

    pub fn send_call<'info>(
        ctx: Context<'_, '_, '_, 'info, SendCallCtx<'info>>,
        envelope: Vec<u8>,
        to: NetworkAddress,
    ) -> Result<u128> {
        instructions::send_call(ctx, envelope, to)
    }

    #[allow(unused_variables)]
    pub fn handle_message(
        ctx: Context<HandleMessageCtx>,
        from_nid: String,
        msg: Vec<u8>,
        sequence_no: u128,
    ) -> Result<()> {
        instructions::handle_message(ctx, from_nid, msg)
    }

    #[allow(unused_variables)]
    pub fn handle_error<'info>(
        ctx: Context<'_, '_, '_, 'info, HandleErrorCtx<'info>>,
        from_nid: String,
        sequence_no: u128,
    ) -> Result<()> {
        instructions::handle_error(ctx, sequence_no)
    }

    pub fn get_fee(
        ctx: Context<GetFeeCtx>,
        nid: String,
        rollback: bool,
        sources: Option<Vec<String>>,
    ) -> Result<u64> {
        instructions::get_fee(ctx, nid, rollback, sources.unwrap_or(vec![]))
    }

    pub fn get_admin(ctx: Context<GetConfigCtx>) -> Result<Pubkey> {
        Ok(ctx.accounts.config.admin)
    }

    pub fn get_protocol_fee(ctx: Context<GetConfigCtx>) -> Result<u64> {
        Ok(ctx.accounts.config.protocol_fee)
    }

    pub fn get_protocol_fee_handler(ctx: Context<GetConfigCtx>) -> Result<Pubkey> {
        Ok(ctx.accounts.config.fee_handler)
    }

    pub fn get_network_address(ctx: Context<GetConfigCtx>) -> Result<NetworkAddress> {
        Ok(NetworkAddress::new(
            &ctx.accounts.config.network_id,
            &id().to_string(),
        ))
    }

    #[allow(unused_variables)]
    pub fn get_default_connection(ctx: Context<GetConfigCtx>, nid: String) -> Result<Pubkey> {
        Ok(ctx.accounts.config.fee_handler)
    }

    pub fn decode_cs_message(_ctx: Context<EmptyContext>, message: Vec<u8>) -> Result<()> {
        instructions::decode_cs_message(message)
    }
}
