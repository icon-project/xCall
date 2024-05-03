use soroban_sdk::{contracttype, Bytes};

use crate::types::message::IMessage;

#[contracttype]
pub struct CallMessagePersisted {
    pub data: Bytes,
}

impl IMessage for CallMessagePersisted {
    fn data(&self) -> Bytes {
        self.data.clone()
    }

    fn rollback(&self) -> Option<Bytes> {
        None
    }
}
