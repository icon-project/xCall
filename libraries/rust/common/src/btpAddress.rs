use cosmwasm_std::{StdError, StdResult};

pub struct BTPAddress;

impl BTPAddress {
    const PREFIX: &'static [u8] = b"btp://";
    const REVERT: &'static str = "invalidBTPAddress";
    const DELIMITER: &'static [u8] = b"/";

    pub fn parse_btp_address(_str: &str) -> StdResult<(&str, &str)> {
        let offset = BTPAddress::_validate(_str)?;
        let network_address = &_str[6..offset];
        let account_address = &_str[offset + 1..];
        Ok((network_address, account_address))
    }

    pub fn parse_network_address(_str: &str) -> StdResult<(&str, &str)> {
        let offset = BTPAddress::_validate_network(_str)?;
        let network_address = &_str[0..offset];
        let account_address = &_str[offset + 1..];
        Ok((network_address, account_address))
    }

    pub fn network_address(_str: &str) -> StdResult<&str> {
        let offset = BTPAddress::_validate(_str)?;
        let network_address = &_str[6..offset];
        Ok(network_address)
    }

    fn _validate(_str: &str) -> StdResult<usize> {
        let bytes = _str.as_bytes();
        for (i, &byte) in bytes.iter().enumerate() {
            if i < 6 {
                if byte != BTPAddress::PREFIX[i] {
                    return Err(StdError::generic_err(BTPAddress::REVERT));
                }
            } else if byte == BTPAddress::DELIMITER[0] {
                if i > 6 && i < (bytes.len() - 1) {
                    return Ok(i);
                } else {
                    return Err(StdError::generic_err(BTPAddress::REVERT));
                }
            }
        }
        Err(StdError::generic_err(BTPAddress::REVERT))
    }

    fn _validate_network(_str: &str) -> StdResult<usize> {
        let bytes = _str.as_bytes();
        for (i, &byte) in bytes.iter().enumerate() {
            if byte == BTPAddress::DELIMITER[0] {
                if i < (bytes.len() - 1) {
                    return Ok(i);
                } else {
                    return Err(StdError::generic_err(BTPAddress::REVERT));
                }
            }
        }
        Err(StdError::generic_err(BTPAddress::REVERT))
    }

    fn _slice(_str: &str, from: usize, to: usize) -> &str {
        &_str[from..to]
    }

    pub fn btp_address(network: &str, account: &str) -> String {
        format!("{:?}{}{:?}{}", BTPAddress::PREFIX, network, BTPAddress::DELIMITER, account)
    }
}

mod tests{
    #[test]
    fn test_parse_btp_address() {
        let btp_address = "btp://0x38.bsc/0x034AaDE86BF402F023Aa17E5725fABC4ab9E9798";
        let (network, account) = super::BTPAddress::parse_btp_address(btp_address).unwrap();
        assert_eq!(network, "0x38.bsc");
        assert_eq!(account, "0x034AaDE86BF402F023Aa17E5725fABC4ab9E9798");
    }

    #[test]
    fn test_parse_network_address() {
        let btp_address = "btp://0x38.bsc/0x034AaDE86BF402F023Aa17E5725fABC4ab9E9798";
        let (network, account) = super::BTPAddress::parse_network_address(btp_address).unwrap();
        assert_eq!(network, "btp:");
        assert_eq!(account, "/0x38.bsc/0x034AaDE86BF402F023Aa17E5725fABC4ab9E9798");
    }

    #[test]
    fn test_network_address() {
        let btp_address = "btp://0x38.bsc/0x034AaDE86BF402F023Aa17E5725fABC4ab9E9798";
        let network = super::BTPAddress::network_address(btp_address).unwrap();
        assert_eq!(network, "0x38.bsc");
    }
}