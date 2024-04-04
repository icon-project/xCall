#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module xcall::network_address {
      use std::string::{Self, String};
    use sui::object::{Self, ID, UID};
    use std::vector;
    use sui_rlp::encoder::{Self};
    use sui_rlp::decoder::{Self};
    use std::debug;

   
   
    struct NetworkAddress has drop,store,copy{
        net_id:String,
        addr:String,
    }

     public fun create(nid:String,addr:String):NetworkAddress {
        return NetworkAddress{
            net_id:nid,
            addr:addr,
        }
    }

    public fun from_string(net_addr:String):NetworkAddress {
        return NetworkAddress {
            net_id:string::utf8(b"nid"),
            addr:string::utf8(b"addr"),
        }
    }

    public fun net_id(self:&NetworkAddress):String {
        self.net_id
    }

     public fun addr(self:&NetworkAddress):String {
        self.addr
    }

    public fun to_string(self:&NetworkAddress):String {
        let addr=self.net_id;
        string::append(&mut addr,string::utf8(b"/"));
        string::append(&mut addr,self.addr);
        addr

    }

    //  public fun as_bytes(self:&NetworkAddress):vector<u8> {
    //     let str=to_string(self);
    //     *string::bytes(str)


    // }

    public fun encode(self:&NetworkAddress):vector<u8>{
        encoder::encode_string(&to_string(self))
    }
    public fun decode(bytes:vector<u8>):NetworkAddress {
        let network_address= decoder::decode_string(&bytes);
        let separator_index=string::index_of(&network_address,&string::utf8(b"/"));
        debug::print(&separator_index);
        let net_id=string::sub_string(&network_address,0,separator_index);
        let addr=string::sub_string(&network_address,separator_index+1,string::length(&network_address));
        create(net_id,addr)
    }

   //  #[test_only] friend xcall::network_address_tests;
}

module xcall::network_address_tests {

    use xcall::network_address::{Self};
     use std::string::{Self, String};
     use sui_rlp::encoder::{Self};
     use sui_rlp::decoder::{Self};
     use std::debug;

    #[test]
    fun test_network_address_encoding(){
        let address=network_address::create(string::utf8(b"netId"),string::utf8(b"address"));
        let bytes= network_address::encode(&address);
        let expected= network_address::decode(bytes);
        assert!(address==expected,0x01);

    }

}