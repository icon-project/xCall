#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module xcall::message_request {
use std::string::{Self, String};
    use sui::object::{Self, ID, UID};
    use xcall::network_address::{Self,NetworkAddress};
    use std::vector::{Self};
     use sui_rlp::encoder::{Self};
    use sui_rlp::decoder::{Self};
    use std::debug;



  struct CSMessageRequest has store,drop{
    from:NetworkAddress,
    to: String,
    sn:u128,
    message_type:u8,
    data:vector<u8>,
    protocols:vector<String>,
   }


    public fun create(from:NetworkAddress,
    to: String,
    sn:u128,
    message_type:u8,
    data:vector<u8>,
    protocols:vector<String>):CSMessageRequest {
        CSMessageRequest {
            from:from,
            to:to,
            sn:sn,
            message_type:message_type,
            data:data,
            protocols:protocols
        }


    }

    public fun encode(req:CSMessageRequest):vector<u8>{
          let list=vector::empty<vector<u8>>();
           vector::push_back(&mut list,network_address::encode(&req.from));
          vector::push_back(&mut list,encoder::encode_string(&req.to));
          vector::push_back(&mut list,encoder::encode_u128(req.sn));
          vector::push_back(&mut list,encoder::encode_u8(req.message_type));
          vector::push_back(&mut list,encoder::encode(&req.data));
          vector::push_back(&mut list,encoder::encode_strings(&req.protocols));

          let encoded=encoder::encode_list(list,false);
          encoded
    }

    

    public fun msg_type(req:&CSMessageRequest):u8 {
         req.message_type
    }


}

module xcall::message_request_tests {
    use xcall::network_address::{Self};
    use xcall::message_request::{Self};
    use std::string;
    use std::vector;
    use std::debug;
    use xcall::call_message::{Self};
     use sui_rlp::encoder::{Self};
    use sui_rlp::decoder::{Self};
    /*
    CSMessageRequest
     from: 0x1.ETH/0xa
     to: cx0000000000000000000000000000000000000102
     sn: 21
     rollback: false
     data: 74657374
     protocol: []
     RLP: F83F8B3078312E4554482F307861AA63783030303030303030303030303030303030303030303030303030303030303030303030303031303215008474657374C0

     CSMessageRequest
     from: 0x1.ETH/0xa
     to: cx0000000000000000000000000000000000000102
     sn: 21
     rollback: false
     data: 74657374
     protocol: [abc, cde, efg]
     RLP: F84B8B3078312E4554482F307861AA63783030303030303030303030303030303030303030303030303030303030303030303030303031303215008474657374CC836162638363646583656667

     CSMessageRequest
     from: 0x1.ETH/0xa
     to: cx0000000000000000000000000000000000000102
     sn: 21
     rollback: true
     data: 74657374
     protocol: [abc, cde, efg]
     RLP: F84B8B3078312E4554482F307861AA63783030303030303030303030303030303030303030303030303030303030303030303030303031303215018474657374CC836162638363646583656667


     */

     #[test]
     fun test_message_request_encode(){
        let from=network_address::create(string::utf8(b"0x1.ETH"),string::utf8(b"0xa"));
        let network_bytes=network_address::encode(&from);
        debug::print(&network_bytes);
        debug::print(&encoder::encode_u128(21));
        debug::print(&encoder::encode_string(&string::utf8(b"cx0000000000000000000000000000000000000102")));
        debug::print(&encoder::encode(&x"74657374"));
        debug::print(&encoder::encode_list(vector::empty(),true));


        let msg_request=message_request::create(from,
        string::utf8(b"cx0000000000000000000000000000000000000102"),
        21,
        call_message::msg_type(),
         x"74657374",
         vector::empty());
         let encoded_bytes=message_request::encode(msg_request);
         debug::print(&encoded_bytes);

     }



     
}