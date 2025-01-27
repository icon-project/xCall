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

package xcall.adapter.cluster;

import java.math.BigInteger;
import score.Context;

import score.Address;
import score.BranchDB;
import score.ByteArrayObjectWriter;
import score.DictDB;
import score.VarDB;
import score.ArrayDB;
import scorex.util.ArrayList;

import score.annotation.EventLog;
import score.annotation.External;
import score.annotation.Payable;

import java.util.List;

public class ClusterConnection {
    protected final VarDB<Address> xCall = Context.newVarDB("callService", Address.class);
    protected final VarDB<Address> adminAddress = Context.newVarDB("admin", Address.class);
    protected final VarDB<Address> relayerAddress = Context.newVarDB("relayer", Address.class);
    protected final VarDB<BigInteger> validatorsThreshold = Context.newVarDB("reqValidatorCnt", BigInteger.class);
    private final VarDB<BigInteger> connSn = Context.newVarDB("connSn", BigInteger.class);
    private final ArrayDB<String> validators = Context.newArrayDB("signers", String.class);

    protected final DictDB<String, BigInteger> messageFees = Context.newDictDB("messageFees", BigInteger.class);
    protected final DictDB<String, BigInteger> responseFees = Context.newDictDB("responseFees", BigInteger.class);
    protected final BranchDB<String, DictDB<BigInteger, Boolean>> receipts = Context.newBranchDB("receipts",
            Boolean.class);

    public ClusterConnection(Address _relayer, Address _xCall) {
        if (xCall.get() == null) {
            xCall.set(_xCall);
            adminAddress.set(Context.getCaller());
            relayerAddress.set(_relayer);
            connSn.set(BigInteger.ZERO);
        }
    }

    /**
     * Retrieves the validators.
     *
     * @return The validators .
     */
    @External(readonly = true)
    public String[] listValidators() {
        String[] sgs = new String[validators.size()];
        for (int i = 0; i < validators.size(); i++) {
            sgs[i] = validators.get(i);
        }
        return sgs;
    }

    /**
     * Adds a list of validators and sets the validation threshold.
     *
     * Clears existing validators and adds the provided addresses as validators.
     * Ensures that the caller is an admin and that the number of validators
     * meets or exceeds the specified threshold.
     *
     * @param _validators an array of compressed publickey bytes to be added as
     *                    validators
     * @param _threshold  the minimum required number of validators
     * @throws Exception if the number of validators is less than the threshold
     */
    @External
    public void updateValidators(byte[][] _validators, BigInteger _threshold) {
        OnlyAdmin();
        clearValidators();
        for (byte[] validator : _validators) {
            String hexValidator = bytesToHex(validator);
            if (!isValidator(hexValidator)) {
                validators.add(bytesToHex(validator));
            }
        }
        Context.require(validators.size() >= _threshold.intValue(), "Not enough validators");
        validatorsThreshold.set(_threshold);
        ValidatorSetAdded(_validators.toString(), _threshold);
    }

    /**
     * Clear the current validators.
     *
     * This is a private helper method called by addValidator.
     */
    private void clearValidators() {
        for (int i = 0; i < validators.size(); i++) {
            validators.set(i, null);
        }
    }

    /**
     * Checks if the provided compressed pubkey bytes is a validator.
     *
     * @param validator the compressed publickey bytes to check for validation
     * @return true if the compressed pubkey bytes is a validator, false otherwise
     */
    private boolean isValidator(String validator) {
        for (int i = 0; i < validators.size(); i++) {
            if (validator.equals(validators.get(i))) {
                return true;
            }
        }
        return false;
    }

    @EventLog(indexed = 2)
    public void Message(String targetNetwork, BigInteger connSn, byte[] msg) {
    }

    @EventLog(indexed = 0)
    public void ValidatorSetAdded(String _validators, BigInteger _threshold) {
    }

    /**
     * Sets the relayer address.
     *
     * @param _relayer the new admin address
     */
    @External
    public void setRelayer(Address _relayer) {
        OnlyAdmin();
        relayerAddress.set(_relayer);
    }

    /**
     * Sets the admin address.
     *
     * @param _admin the new admin address
     */
    @External
    public void setAdmin(Address _admin) {
        OnlyAdmin();
        adminAddress.set(_admin);
    }

    /**
     * Retrieves the admin address.
     *
     * @return The admin address.
     */
    @External(readonly = true)
    public Address admin() {
        return adminAddress.get();
    }

    /**
     * Sets the required validator count
     *
     * @param _validatorCnt the new required validator count
     */
    @External
    public void setRequiredValidatorCount(BigInteger _validatorCnt) {
        OnlyAdmin();
        validatorsThreshold.set(_validatorCnt);
    }

    /**
     * Retrieves the required validator count.
     *
     * @return The required validator count.
     */
    @External(readonly = true)
    public BigInteger requiredValidatorCount() {
        return validatorsThreshold.get();
    }

    /**
     * Sets the fee to the target network
     *
     * @param networkId   String Network Id of target chain
     * @param messageFee  The fee needed to send a Message
     * @param responseFee The fee of the response
     */
    @External
    public void setFee(String networkId, BigInteger messageFee, BigInteger responseFee) {
        OnlyRelayer();
        messageFees.set(networkId, messageFee);
        responseFees.set(networkId, responseFee);
    }

    /**
     * Returns the fee associated with the given destination address.
     *
     * @param to       String Network Id of target chain
     * @param response whether the responding fee is included
     * @return The fee of sending a message to a given destination network
     */
    @External(readonly = true)
    public BigInteger getFee(String to, boolean response) {
        BigInteger messageFee = messageFees.getOrDefault(to, BigInteger.ZERO);
        if (response) {
            BigInteger responseFee = responseFees.getOrDefault(to, BigInteger.ZERO);
            return messageFee.add(responseFee);
        }
        return messageFee;
    }

    /**
     * Sends a message to the specified network.
     *
     * @param to  Network Id of destination network
     * @param svc name of the service
     * @param sn  positive for two-way message, zero for one-way message, negative
     *            for response(for xcall message)
     * @param msg serialized bytes of Service Message
     */
    @Payable
    @External
    public void sendMessage(String to, String svc, BigInteger sn, byte[] msg) {
        Context.require(Context.getCaller().equals(xCall.get()), "Only xCall can send messages");
        BigInteger fee = BigInteger.ZERO;
        if (sn.compareTo(BigInteger.ZERO) > 0) {
            fee = getFee(to, true);
        } else if (sn.equals(BigInteger.ZERO)) {
            fee = getFee(to, false);
        }

        BigInteger nextConnSn = connSn.get().add(BigInteger.ONE);
        connSn.set(nextConnSn);

        Context.require(Context.getValue().compareTo(fee) >= 0, "Insufficient balance");
        Message(to, nextConnSn, msg);
    }

    /**
     * Receives a message from a source network.
     *
     * @param srcNetwork the source network id from which the message is received
     * @param _connSn    the serial number of the connection message
     * @param msg        serialized bytes of Service Message
     * @param dstNetwork the destination network id
     * @param signatures array of signatures
     */
    @External
    public void recvMessageWithSignatures(
            String srcNetwork,
            BigInteger _connSn,
            byte[] msg,
            byte[][] signatures) {
        OnlyRelayer();
        Context.require(signatures.length >= validatorsThreshold.get().intValue(), "Not enough signatures");

        String dstNetwork = Context.call(String.class, xCall.get(), "getNetworkId");

        byte[] messageHash = getMessageHash(srcNetwork, _connSn, msg, dstNetwork);
        List<String> uniqueValidators = new ArrayList<>();
        for (byte[] signature : signatures) {
            byte[] validator = getValidator(messageHash, signature);
            String hexValidator = bytesToHex(validator);
            if (isValidator(hexValidator) && !uniqueValidators.contains(hexValidator)) {
                uniqueValidators.add(hexValidator);
            }
            if (uniqueValidators.size() >= validatorsThreshold.get().intValue()) {
                break;
            }
        }
        Context.require(uniqueValidators.size() >= validatorsThreshold.get().intValue(), "Not enough valid signatures");
        recvMessage(srcNetwork, _connSn, msg);
    }

    private void recvMessage(String srcNetwork, BigInteger _connSn, byte[] msg) {
        Context.require(!receipts.at(srcNetwork).getOrDefault(_connSn, false), "Duplicate Message");
        receipts.at(srcNetwork).set(_connSn, true);
        Context.call(xCall.get(), "handleMessage", srcNetwork, msg);
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder hexString = new StringBuilder();
        for (byte b : bytes) {
            String hex = Integer.toHexString(0xff & b); // Mask with 0xff to handle negative values correctly
            if (hex.length() == 1) {
                hexString.append('0'); // Add a leading zero if hex length is 1
            }
            hexString.append(hex);
        }
        return hexString.toString();
    }

    private byte[] getValidator(byte[] msg, byte[] sig) {
        return Context.recoverKey("ecdsa-secp256k1", msg, sig, false);
    }

    /**
     * Reverts a message.
     *
     * @param sn the serial number of xcall message representing the message to
     *           revert
     */
    @External
    public void revertMessage(BigInteger sn) {
        OnlyRelayer();
        Context.call(xCall.get(), "handleError", sn);
    }

    /**
     * Claim the fees.
     *
     */
    @External
    public void claimFees() {
        OnlyRelayer();
        Context.transfer(relayerAddress.get(), Context.getBalance(Context.getAddress()));
    }

    /**
     * Get the receipts for a given source network and serial number.
     *
     * @param srcNetwork the source network id
     * @param _connSn    the serial number of connection message
     * @return the receipt if is has been recived or not
     */
    @External(readonly = true)
    public boolean getReceipts(String srcNetwork, BigInteger _connSn) {
        return receipts.at(srcNetwork).getOrDefault(_connSn, false);
    }

    /**
     * Checks if the caller of the function is the admin.
     *
     * @return true if the caller is the admin, false otherwise
     */
    private void OnlyRelayer() {
        Context.require(Context.getCaller().equals(relayerAddress.get()), "Only relayer can call this function");
    }

    /**
     * Checks if the caller of the function is the admin.
     *
     * @return true if the caller is the admin, false otherwise
     */
    private void OnlyAdmin() {
        Context.require(Context.getCaller().equals(adminAddress.get()), "Only admin can call this function");
    }

    /**
     * Gets the hash of a message.
     * 
     * @param srcNetwork the source network id
     * @param _connSn    the serial number of connection message
     * @param msg        the message to hash
     * @param dstNetwork the destination network id
     * @return the hash of the message
     */
    private byte[] getMessageHash(String srcNetwork, BigInteger _connSn, byte[] msg, String dstNetwork) {
        byte[] result = concatBytes(srcNetwork.getBytes(), String.valueOf(_connSn).getBytes(), msg, dstNetwork.getBytes());
        return Context.hash("keccak-256", result);
    }

    private static byte[] concatBytes(byte[]... arrays) {
        int totalLength = 0;
        for (byte[] array : arrays) {
            totalLength += array.length;
        }
        byte[] result = new byte[totalLength];
        int currentIndex = 0;
        for (byte[] array : arrays) {
            System.arraycopy(array, 0, result, currentIndex, array.length);
            currentIndex += array.length;
        }
        return result;
    }


}