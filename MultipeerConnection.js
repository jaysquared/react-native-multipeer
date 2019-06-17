import { DeviceEventEmitter, NativeModules } from 'react-native';
import { EventEmitter } from 'events';
import Peer from './Peer';

const RCTMultipeerConnectivity = NativeModules.MultipeerConnectivity;

export default class MultipeerConnection extends EventEmitter {
    constructor() {
        super();
        this._peers = {};
        this._connectedPeers = {};
        var peerFound = DeviceEventEmitter.addListener(
            'RCTMultipeerConnectivityPeerFound',
            (event => {
                var peer = new Peer(event.peer.id, event.peer.info.name, evefnt.peer.info);
                this._peers[peer.id] = peer;
                // console.log('peerFound', event);
                this.emit('peerFound', { peer });
            }).bind(this)
        );

        var peerLost = DeviceEventEmitter.addListener(
            'RCTMultipeerConnectivityPeerLost',
            (event => {
                var peer = this._peers[event.peer.id];
                delete this._peers[event.peer.id];
                delete this._connectedPeers[event.peer.id];
                peer.emit('lost');
                // console.log('peerLost', event);
                this.emit('peerLost', { peer: { id: peer.id } });
            }).bind(this)
        );

        var peerConnected = DeviceEventEmitter.addListener(
            'RCTMultipeerConnectivityPeerConnected',
            (event => {
                this._peers[event.peer.id] &&
                this._peers[event.peer.id].emit('connected');
                this._connectedPeers[event.peer.id] = this._peers[event.peer.id];
                // console.log('peerConnected', event);
                this.emit('peerConnected', event);
            }).bind(this)
        );

        var peerConnecting = DeviceEventEmitter.addListener(
            'RCTMultipeerConnectivityPeerConnecting',
            (event => {
                this._peers[event.peer.id] &&
                this._peers[event.peer.id].emit('connecting');
                // console.log('peerConnecting', event);
                this.emit('peerConnecting', event);
            }).bind(this)
        );

        var peerDisconnected = DeviceEventEmitter.addListener(
            'RCTMultipeerConnectivityPeerDisconnected',
            (event => {
                this._peers[event.peer.id] &&
                this._peers[event.peer.id].emit('disconnected');
                delete this._connectedPeers[event.peer.id];
                // console.log('peerDisconnected', event)
                this.emit('peerDisconnected', event);
            }).bind(this)
        );

        var streamOpened = DeviceEventEmitter.addListener(
            'RCTMultipeerConnectivityStreamOpened',
            (event => {
                this.emit('streamOpened', event);
            }).bind(this)
        );

        var invited = DeviceEventEmitter.addListener(
            'RCTMultipeerConnectivityInviteReceived',
            (event => {
                // console.log("In JS API with an invite from:", event.peer.id);
                event.sender = this._peers[event.peer.id];
                this.emit('invite', event);
            }).bind(this)
        );

        var dataReceived = DeviceEventEmitter.addListener(
            'RCTMultipeerConnectivityDataReceived',
            (event => {
                if (event.peer) {
                    event.sender = this._peers[event.peer.id];
                }
                this.emit('data', event);
            }).bind(this)
        );
    }

    getAllPeers() {
        return this._peers;
    }

    getConnectedPeers() {
        return this._connectedPeers;
    }

    getPeerName(peerId)
    {
        return this._peers[peerId].name;
    }

    sendToConnectedPeers(data, callback) {
        if (!callback) {
            callback = () => {};
        }

        RCTMultipeerConnectivity.sendToConnectedPeers(data, callback);
    }

    /* Removed in Native library for now. */
    // send(recipients, data, callback) {
    //     if (!callback) {
    //         callback = () => {};
    //     }

    //     var recipientIds = recipients.map(recipient => {
    //         if (recipient instanceof Peer) {
    //             console.log('recipient is a peer');
    //             return recipient.id;
    //         }
    //         console.log('recipient is not a peer');
    //         return recipient;
    //     });
    //     console.log('sending data', data, 'to', recipientIds);
    //     RCTMultipeerConnectivity.send(recipientIds, data, callback);
    //}

    invite(peerId, callback) {
        if (!callback) {
            callback = () => {};
        }
        RCTMultipeerConnectivity.invite(peerId, callback);
    }

    rsvp(inviteId, accept, callback) {
        if (!callback) {
            callback = () => {};
        }
        // console.log("In JS API RSVP");
        RCTMultipeerConnectivity.rsvp(inviteId, accept, callback);
    }

    advertise(channel, info) {
        RCTMultipeerConnectivity.advertise(channel, info);
    }

    stopAdvertising() {
        RCTMultipeerConnectivity.stopAdvertising();
    }

    browse(channel) {
        RCTMultipeerConnectivity.browse(channel);
    }

    stopBrowsing() {
        RCTMultipeerConnectivity.stopBrowsing();
    }

    disconnectFromAll(callback) {
        if (!callback) {
            callback = () => {};
        }
        RCTMultipeerConnectivity.disconnectFromAll(callback);
    }

    disconnectFromPeer(peerId, callback) {
        if (!callback) {
            callback = () => {};
        }
        RCTMultipeerConnectivity.disconnectFromPeer(peerId, callback);
    }

    // logSessionInfo() {
    //     RCTMultipeerConnectivity.logSessionInfo();
    // }
}