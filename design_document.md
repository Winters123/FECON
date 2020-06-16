### FECON: FAST-enabled Corundum NIC [design document]

---

#### Contributors:



#### Why we need FECON?

Corundum is an opensource FPGA-based NIC design that offers great flexibility for network experimentations specifically on the NIC side. Currently, Corundum has support several main stream FPGA-based programmable NICs on the market. 

However, reusing Corundum code base for some agile NIC experimentation is not easy (e.g., for  QUIC acceleration, we need extract pkt type and other protocol related fields conveniently). This is based on several reasons:

1. there is no metadata mechanism that can be used for easy packet parsing/matching/modification;
2. its not easy enough to insert user-defined modules for customization.

Fortunately, both two are the key advantages provided by FAST framework. Integrating FAST pipeline within corundum can greatly magnify the convenience brought by Corundum when you mess up with FPGA-based NICs.

#### How to integrate FAST into Corundum? (the tradeoffs)

Basically, there are two ways to plug FAST inside Corundum: partial plugin && complete plugin.

**Partial plugin:** In this mode, only the hardware functions of FAST are inserted. This means that users can use the abstractions (i.e. UM) on the hardware for packet processing. However, FAST software components cannot be used (i.e. UA). 

**Complete plugin:** In this mode, both FAST hardware pipeline and software API are integrated with corundum. Thus, a complete FAST abstraction is enabled, including its software components.

**Difference between two modes:** The main difference is whether we need to ***change the datapath format*** in Corundum's current design.

 

**[This part is only the initial thought and does not represent the actual implementation]**

![image-20200527230442397](F:/2020/FPGA-Network/FECON/partial_design.png)

Fig. 1 is a block design for **partial plugin mode**. The plugged modules (in blue) are inserted between `interface.v` and `eth_mac`. On the rx path, the metadata is added when the packet is read out from `rx_fifo`; On the tx path, the metadata is added when the packet is read out from `port.v`. Since once the processing of FAST pipeline finished the metadata field will be stripped from the packet, such a design will not change the datapath format of Corundum.

![image-20200528000528600](F:/2020/FPGA-Network/FECON/complete_design.png)

Fig. 2 is a block design for **complete plugin mode**. The modules (blue) are inserted between `dma_client_axis_source/dma_client_axis_sink.v` and `tx/rx checksum.v`. Be noted that there is no metadata detach module between DMA && FAST pipeline. 



#### Reference (Original Design)

##### Block Diagram

![Corundum block diagram](F:/2020/FPGA-Network/FECON/block.svg)

Block diagram of the Corundum NIC. PCIe HIP: PCIe hard IP core; AXIL M: AXI lite master; DMA IF: DMA interface; PTP HC: PTP hardware clock; TXQ: transmit queue manager; TXCQ: transmit completion queue manager; RXQ: receive queue manager; RXCQ: receive completion queue manager; EQ: event queue manager; MAC + PHY: Ethernet media access controller (MAC) and physical interface layer (PHY).

##### Modules

###### cmac_pad module

Frame pad module for 512 bit 100G CMAC TX interface.  Zero pads transmit
frames to minimum 64 bytes.

###### cpl_op_mux module

Completion operation multiplexer module.  Merges completion write operations
from different sources to enable sharing a single cpl_write module instance.

###### cpl_queue_manager module

Completion queue manager module.  Stores device to host queue state in block
RAM or ultra RAM.

###### cpl_write module

Completion write module.  Responsible for enqueuing completion and event
records into the completion queue managers and writing records into host
memory via DMA.

###### desc_fetch module

Descriptor fetch module.  Responsible for dequeuing descriptors from the queue
managers and reading descriptors from host memory via DMA.

###### desc_op_mux module

Descriptor operation multiplexer module.  Merges descriptor fetch operations
from different sources to enable sharing a single desc_fetch module instance.

###### event_mux module

Event mux module.  Enables multiple event sources to feed the same event queue.

###### interface module

Interface module.  Contains the event queues, interface queues, and ports.

###### port module

Port module.  Contains the transmit and receive datapath components, including
transmit and receive engines and checksum and hash offloading.

###### queue_manager module

Queue manager module.  Stores host to device queue state in block RAM or ultra
RAM.

###### rx_checksum module

Receive checksum computation module.  Computes 16 bit checksum of Ethernet
frame payload to aid in IP checksum offloading.

###### rx_engine module

Receive engine.  Manages receive datapath operations including descriptor
dequeue and fetch via DMA, packet reception, data writeback via DMA, and
completion enqueue and writeback via DMA.  Handles PTP timestamps for
inclusion in completion records.

###### rx_hash module

Receive hash computation module.  Extracts IP addresses and ports from packet
headers and computes 32 bit Toeplitz flow hash.

###### tdma_ber_ch module

TDMA bit error ratio (BER) test channel module.  Controls PRBS logic in
Ethernet PHY and accumulates bit errors.  Can be configured to bin error
counts by TDMA timeslot.

###### tdma_ber module

TDMA bit error ratio (BER) test module.  Wrapper for a tdma_scheduler and
multiple instances of tdma_ber_ch.

###### tdma_scheduler module

TDMA scheduler module.  Generates TDMA timeslot index and timing signals from
PTP time.

###### tx_checksum module

Transmit checksum computation and insertion module.  Computes 16 bit checksum
of frame data with specified start offset, then inserts computed checksum at
the specified position.

###### tx_engine module

Transmit engine.  Manages transmit datapath operations including descriptor
dequeue and fetch via DMA, packet data fetch via DMA, packet transmission, and
completion enqueue and writeback via DMA.  Handles PTP timestamps for
inclusion in completion records.

###### tx_scheduler_ctrl_tdma module

TDMA transmit scheduler control module.  Controls queues in a transmit
scheduler based on PTP time, via a tdma_scheduler instance.

###### tx_scheduler_rr module

Round-robin transmit scheduler.  Determines which queues from which to send
packets.

##### Source Files

    cmac_pad.v               : Pad frames to 64 bytes for CMAC TX
    cpl_op_mux.v             : Completion operation mux
    cpl_queue_manager.v      : Completion queue manager
    cpl_write.v              : Completion write module
    desc_fetch.v             : Descriptor fetch module
    desc_op_mux.v            : Descriptor operation mux
    event_mux.v              : Event mux
    event_queue.v            : Event queue
    interface.v              : Interface
    port.v                   : Port
    queue_manager.v          : Queue manager
    rx_checksum.v            : Receive checksum offload
    rx_engine.v              : Receive engine
    rx_hash.v                : Receive hashing module
    tdma_ber_ch.v            : TDMA BER channel
    tdma_ber.v               : TDMA BER
    tdma_scheduler.v         : TDMA scheduler
    tx_checksum.v            : Transmit checksum offload
    tx_engine.v              : Transmit engine
    tx_scheduler_ctrl_tdma.v : TDMA transmit scheduler controller
    tx_scheduler_rr.v        : Round robin transmit scheduler

---



