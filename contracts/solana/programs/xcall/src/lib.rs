use anchor_lang::prelude::*;

pub mod constants;
pub mod error;
pub mod event;
pub mod instructions;
pub mod state;
pub mod types;

use instructions::*;
use state::*;

use xcall_lib::{message::envelope::Envelope, network_address::NetworkAddress};

declare_id!("DoSLJH36FLrQVjZ8wDD4tHHfLbisj4VwMzpvTV9yyyp2");

#[program]
pub mod xcall {
    use super::*;

    pub fn initialize(ctx: Context<ConfigCtx>, network_id: String) -> Result<()> {
        ctx.accounts
            .config
            .set_inner(Config::new(ctx.accounts.signer.key(), network_id));

        ctx.accounts.reply.set_inner(Reply {
            reply_state: None,
            call_reply: None,
        });

        Ok(())
    }

    pub fn set_admin(ctx: Context<UpdateConfigCtx>, account: Pubkey) -> Result<()> {
        ctx.accounts
            .config
            .ensure_admin(ctx.accounts.signer.key())?;

        ctx.accounts.config.set_admin(account);

        Ok(())
    }

    pub fn set_protocol_fee(ctx: Context<UpdateConfigCtx>, fee: u128) -> Result<()> {
        ctx.accounts
            .config
            .ensure_fee_handler(ctx.accounts.signer.key())?;

        ctx.accounts.config.set_protocol_fee(fee);

        Ok(())
    }

    pub fn set_protocol_fee_handler(
        ctx: Context<UpdateConfigCtx>,
        fee_handler: Pubkey,
    ) -> Result<()> {
        ctx.accounts
            .config
            .ensure_admin(ctx.accounts.signer.key())?;

        ctx.accounts.config.set_fee_handler(fee_handler);

        Ok(())
    }

    #[allow(unused_variables)]
    pub fn set_default_connection(
        ctx: Context<DefaultConnectionCtx>,
        network_id: String,
        connection: Pubkey,
    ) -> Result<()> {
        ctx.accounts
            .config
            .ensure_admin(ctx.accounts.signer.key())?;

        ctx.accounts.default_connection.set(connection);

        Ok(())
    }

    pub fn send_call(
        ctx: Context<SendCallCtx>,
        envelope: Envelope,
        to: NetworkAddress,
    ) -> Result<u128> {
        instructions::send_call(ctx, envelope, to)
    }

    #[allow(unused_variables)]
    pub fn handle_message(
        ctx: Context<HandleMessageCtx>,
        from_nid: String,
        message: Vec<u8>,
        req_id: u128,
        sequence_no: u128,
        message_seed: Vec<u8>,
    ) -> Result<()> {
        instructions::handle_message(ctx, from_nid, message, message_seed)
    }
}
