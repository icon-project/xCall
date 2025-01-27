use anchor_lang::{
    prelude::*,
    solana_program::{
        hash, instruction::{AccountMeta,Instruction}, keccak::hashv, program::{get_return_data, invoke, invoke_signed}, secp256k1_recover::secp256k1_recover, system_instruction
    },
};

use crate::contexts::*;
use crate::state::*;
use crate::error::*;

use xcall_lib::{network_address:: NetworkAddress, xcall_type};

pub const GET_NETWORK_ADDRESS: &str = "get_network_address";

pub fn transfer_lamports<'info>(
    from: &AccountInfo<'info>,
    to: &AccountInfo<'info>,
    system_program: &AccountInfo<'info>,
    amount: u64,
) -> Result<()> {
    let ix = system_instruction::transfer(&from.key(), &to.key(), amount);
    invoke(
        &ix,
        &[from.to_owned(), to.to_owned(), system_program.to_owned()],
    )?;

    Ok(())
}

pub fn get_instruction_data(ix_name: &str, data: Vec<u8>) -> Vec<u8> {
    let preimage = format!("{}:{}", "global", ix_name);

    let mut ix_discriminator = [0u8; 8];
    ix_discriminator.copy_from_slice(&hash::hash(preimage.as_bytes()).to_bytes()[..8]);

    let mut ix_data = Vec::new();
    ix_data.extend_from_slice(&ix_discriminator);
    ix_data.extend_from_slice(&data);

    ix_data
}

pub fn get_message_hash(from_nid: &String, connection_sn: &u128, message: &Vec<u8>, dst_nid: &String) -> [u8; 32] {
    let mut encoded_bytes = Vec::new();
    encoded_bytes.extend(from_nid.as_bytes());
    encoded_bytes.extend(connection_sn.to_string().as_bytes());
    encoded_bytes.extend(message);
    encoded_bytes.extend(dst_nid.as_bytes());

    let hash = hashv(&[&encoded_bytes]);

    hash.to_bytes()
}

pub fn recover_pubkey(message: [u8; 32], sig: [u8; 65]) -> [u8; 64] {
    let recovery_id = sig[64] % 27;
    let signature = &sig[0..64];
    let recovered_pubkey = secp256k1_recover(&message, recovery_id, signature).unwrap();
    recovered_pubkey.to_bytes()
}   

pub fn get_nid(xcall_config: &AccountInfo, config: &Config) -> String {
    let ix_data = get_instruction_data(GET_NETWORK_ADDRESS, vec![]);
    let account_metas = vec![AccountMeta::new(xcall_config.key(), false)];
    let account_infos = vec![xcall_config.to_account_info()];

    let ix = Instruction {
        program_id: config.xcall,
        accounts: account_metas,
        data: ix_data,
    };

    invoke(&ix, &account_infos).unwrap();

    let network_address = NetworkAddress::try_from_slice(&get_return_data().unwrap().1).unwrap();
    return network_address.nid().to_string();  
}

pub fn call_xcall_handle_message_with_signatures<'info>(
    ctx: Context<'_, '_, '_, 'info, ReceiveMessageWithSignatures<'info>>,
    from_nid: String,
    message: Vec<u8>,
    conn_sn: u128,
    sequence_no: u128,
    signatures: Vec<[u8; 65]>,
) -> Result<()> {
    let mut data = vec![];
    let dst_nid = get_nid(&ctx.remaining_accounts[1], &ctx.accounts.config);
    let message_hash = get_message_hash(&from_nid, &conn_sn, &message, &dst_nid);
    let mut unique_validators = Vec::new();
    for sig in signatures {
        let pubkey = recover_pubkey(message_hash, sig);
        if !unique_validators.contains(&pubkey) && ctx.accounts.config.is_validator(&pubkey) {
            unique_validators.push(pubkey);
        } 
        if (unique_validators.len() as u8) >= ctx.accounts.config.threshold {
            break;
        }
    }

    if (unique_validators.len() as u8) < ctx.accounts.config.threshold {
        return Err(ConnectionError::ValidatorsMustBeGreaterThanThreshold.into());
    }

    let args = xcall_type::HandleMessageArgs {
        from_nid,
        message,
        sequence_no,
        conn_sn,
    };
    args.serialize(&mut data)?;

    let ix_data = get_instruction_data("handle_message", data);

    invoke_instruction(
        ix_data,
        &ctx.accounts.config,
        &ctx.accounts.authority,
        &ctx.accounts.relayer,
        &ctx.accounts.system_program,
        ctx.remaining_accounts,
    )
}

pub fn call_xcall_handle_error<'info>(
    ctx: Context<'_, '_, '_, 'info, RevertMessage<'info>>,
    sequence_no: u128,
) -> Result<()> {
    let mut data = vec![];
    let args = xcall_type::HandleErrorArgs { sequence_no };
    args.serialize(&mut data)?;

    let ix_data = get_instruction_data("handle_error", data);

    invoke_instruction(
        ix_data,
        &ctx.accounts.config,
        &ctx.accounts.authority,
        &ctx.accounts.relayer,
        &ctx.accounts.system_program,
        &ctx.remaining_accounts,
    )
}

pub fn invoke_instruction<'info>(
    ix_data: Vec<u8>,
    config: &Account<'info, Config>,
    authority: &Account<'info, Authority>,
    admin: &Signer<'info>,
    system_program: &Program<'info, System>,
    remaining_accounts: &[AccountInfo<'info>],
) -> Result<()> {
    let mut account_metas = vec![
        AccountMeta::new(admin.key(), true),
        AccountMeta::new_readonly(authority.key(), true),
        AccountMeta::new_readonly(system_program.key(), false),
    ];
    let mut account_infos = vec![
        admin.to_account_info(),
        authority.to_account_info(),
        system_program.to_account_info(),
    ];
    for i in remaining_accounts {
        if i.is_writable {
            account_metas.push(AccountMeta::new(i.key(), i.is_signer));
        } else {
            account_metas.push(AccountMeta::new_readonly(i.key(), i.is_signer))
        }
        account_infos.push(i.to_account_info());
    }
    let ix = Instruction {
        program_id: config.xcall,
        accounts: account_metas,
        data: ix_data.clone(),
    };

    invoke_signed(
        &ix,
        &account_infos,
        &[&[Authority::SEED_PREFIX.as_bytes(), &[authority.bump]]],
    )?;

    Ok(())
}



#[test]
fn test_recover_pubkey() {
    let from_nid = "0x2.icon";
    let connection_sn = 128;
    let message = b"hello";
    let dst_nid = "archway";

    let message_hash = get_message_hash(&from_nid.to_string(), &connection_sn, &message.to_vec(), &dst_nid.to_string());   

    let signature = [102,13,84,43,63,109,233,205,8,242,56,253,68,19,62,238,191,234,41,11,33,218,231,50,42,99,181,22,197,123,141,241,44,76,10,52,11,96,237,86,124,141,165,53,120,52,108,33,43,39,183,151,235,66,167,95,180,183,7,108,86,122,111,249,28];
    let pubkey = recover_pubkey(message_hash, signature);
    print!("pubkey: {:?}", pubkey);
    assert_eq!(pubkey, [222,202,81,45,92,184,118,115,178,58,177,12,62,53,114,227,10,43,93,199,140,213,0,191,132,191,6,98,117,192,187,50,12,182,205,38,106,161,121,180,19,35,181,161,138,180,161,112,36,142,216,155,67,107,85,89,186,179,140,129,108,225,34,9] );
}
