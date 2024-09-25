/*
 * Copyright 2022 ICON Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package relay.aggregator;

import java.math.BigInteger;

import score.Context;
import score.Address;
import score.ArrayDB;
import score.VarDB;
import score.DictDB;
import score.BranchDB;
import score.annotation.EventLog;
import score.annotation.External;
import scorex.util.ArrayList;

public class RelayAggregator {
    private final VarDB<Address> admin = Context.newVarDB("admin", Address.class);

    private final ArrayDB<Address> relayers = Context.newArrayDB("relayers", Address.class);

    private final DictDB<String, Packet> packets = Context.newDictDB("packets", Packet.class);

    private final BranchDB<String, DictDB<Address, byte[]>> signatures = Context.newBranchDB("signatures",
            byte[].class);

    public RelayAggregator(Address _admin, Address[] _relayers) {
        if (admin.get() == null) {
            admin.set(_admin);
            for (Address relayer : _relayers) {
                relayers.add(relayer);
            }
        }
    }

    @External
    public void setAdmin(Address _admin) {
        adminOnly();
        admin.set(_admin);
    }

    @External(readonly = true)
    public Address getAdmin() {
        return admin.get();
    }

    @External
    public void registerPacket(
            String srcNetwork,
            String contractAddress,
            BigInteger srcSn,
            String dstNetwork,
            byte[] data) {

        adminOnly();

        Packet pkt = new Packet(srcNetwork, contractAddress, srcSn, dstNetwork, data);
        String id = pkt.getId();

        Context.require(packets.get(id) == null, "Packet already exists");

        packets.set(id, pkt);

        PacketRegistered(pkt.getSrcNetwork(), pkt.getContractAddress(), pkt.getSrcSn());
    }

    @External
    public void submitSignature(
            String srcNetwork,
            String contractAddress,
            BigInteger srcSn,
            byte[] signature) {

        relayersOnly();

        String pktID = Packet.createId(srcNetwork, contractAddress, srcSn);
        Packet pkt = packets.get(pktID);
        Context.require(pkt != null, "Packet not registered");

        byte[] existingSign = signatures.at(pktID).get(Context.getCaller());
        Context.require(existingSign == null, "Signature already exists");

        setSignature(pktID, Context.getCaller(), signature);

        if (signatureThresholdReached(pktID)) {
            PacketConfirmed(
                    pkt.getSrcNetwork(),
                    pkt.getContractAddress(),
                    pkt.getSrcSn(),
                    pkt.getDstNetwork(),
                    pkt.getData());
        }
    }

    @External(readonly = true)
    public ArrayList<byte[]> getSignatures(String srcNetwork, String contractAddress, BigInteger srcSn) {
        String pktID = Packet.createId(srcNetwork, contractAddress, srcSn);
        DictDB<Address, byte[]> signDict = signatures.at(pktID);
        ArrayList<byte[]> signatureList = new ArrayList<byte[]>();

        for (int i = 0; i < relayers.size(); i++) {
            Address relayer = relayers.get(i);
            byte[] sign = signDict.get(relayer);
            if (sign != null) {
                signatureList.add(sign);
            }
        }
        return signatureList;
    }

    protected void setSignature(String pktID, Address addr, byte[] sign) {
        signatures.at(pktID).set(addr, sign);
    }

    private void adminOnly() {
        Context.require(Context.getCaller().equals(admin.get()), "Unauthorized: caller is not the leader relayer");
    }

    private void relayersOnly() {
        Address caller = Context.getCaller();
        Boolean isRelayer = false;
        for (int i = 0; i < relayers.size(); i++) {
            Address relayer = relayers.get(i);
            if (relayer.equals(caller)) {
                isRelayer = true;
                break;
            }
        }
        Context.require(isRelayer, "Unauthorized: caller is not a registered relayer");
    }

    private Boolean signatureThresholdReached(String pktID) {
        int noOfSignatures = 0;
        for (int i = 0; i < relayers.size(); i++) {
            Address relayer = relayers.get(i);
            byte[] relayerSign = signatures.at(pktID).get(relayer);
            if (relayerSign != null) {
                noOfSignatures++;
            }
        }
        int threshold = (relayers.size() * 66) / 100;
        return noOfSignatures >= threshold;
    }

    @EventLog(indexed = 2)
    public void PacketRegistered(
            String srcNetwork,
            String contractAddress,
            BigInteger srcSn) {
    }

    @EventLog(indexed = 2)
    public void PacketConfirmed(
            String srcNetwork,
            String contractAddress,
            BigInteger srcSn,
            String dstNetwork,
            byte[] data) {
    }
}