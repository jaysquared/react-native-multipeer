import { EventEmitter } from 'events';

export default class Peer extends EventEmitter {
  constructor(id, name, other) {
    super();
    this.id = id;
    this.name = name;
    this.other = other
  }
}
