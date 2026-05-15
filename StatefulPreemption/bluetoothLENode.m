classdef bluetoothLENode < wirelessnetwork.internal.wirelessNode
%bluetoothLENode Bluetooth LE node
%   LENODE = bluetoothLENode(ROLE) creates a default Bluetooth(R) low
%   energy (LE) node object for the specified role, ROLE.
%
%   LENODE = bluetoothLENode(ROLE, Name=Value) creates a Bluetooth LE node
%   object, LENODE, with the specified property Name set to the specified
%   Value. You can specify additional name-value arguments in any order as
%   (Name1=Value1, ..., NameN=ValueN).
%
%   ROLE specifies the role of the created Bluetooth LE node. Set this
%   value as one of "broadcaster", "observer", "central", "peripheral",
%   "isochronous-broadcaster", "synchronized-receiver", or
%   "broadcaster-observer".
%
%   bluetoothLENode properties (configurable):
%
%   Name                  - Node name
%   Position              - Node position
%   TransmitterPower      - Signal transmission power in dBm
%   TransmitterGain       - Transmitter antenna gain in dB
%   ReceiverRange         - Packet reception range of the node in meters
%   ReceiverGain          - Receiver antenna gain in dB
%   ReceiverSensitivity   - Receiver sensitivity in dBm
%   NoiseFigure           - Noise figure in dB
%   AdvertisingInterval   - Advertising interval in seconds
%   RandomAdvertising     - Random advertising channel selection
%   ScanInterval          - Scan interval in seconds
%   MeshConfig            - Bluetooth mesh configuration object for
%                          "broadcaster-observer" role
%   InterferenceModeling  - Type of interference modeling
%   MaxInterferenceOffset - Maximum frequency offset to determine the
%                           interfering signal
%   InterferenceFidelity  - Fidelity level to model interference
%
%   bluetoothLENode properties (read-only):
%
%   ID                        - Node identifier
%   Role                      - Role of the Bluetooth LE node
%   ConnectionConfig          - Connection configuration object for
%                               "central" and "peripheral" roles
%   CISConfig                 - Connected isochronous stream (CIS) connection
%                               configuration for "central" and "peripheral" roles
%   PeriodicAdvConfig         - Periodic advertisement configuration object
%                               for "broadcaster" and "observer" roles
%   PeripheralCount           - Number of peripherals associated with the central
%   BIGConfig                 - BIG configuration object for "isochronous-broadcaster"
%                               and "synchronized-receiver" roles
%   FriendshipConfig          - Friendship configuration object for a Friend and
%                               low power node (LPN)
%
%   bluetoothLENode methods:
%
%   addTrafficSource       - Add data traffic source to Bluetooth LE node
%   updateChannelList      - Provide updated channel list to Bluetooth LE node
%   statistics             - Get the statistics of Bluetooth LE node
%   addMobility            - Add random waypoint mobility model to Bluetooth LE node
%
%   bluetoothLENode events:
%
%   PacketTransmissionStarted - Event to notify the start of a signal
%                               transmission
%   PacketReceptionEnded      - Event to notify the end of a signal 
%                               reception
%   ChannelMapUpdated         - Event to notify the enforcement of new 
%                               channel map
%   AppDataReceived           - Event to notify the reception of 
%                               application data
%   MeshAppDataReceived       - Event to notify the reception of mesh
%                               application data
%   ConnectionEventEnded      - Event to notify the end of a ConnectionEvent
%
%   Example 1: Create, Configure, and Simulate Bluetooth LE Network
%   <a
%   href="matlab:helpview('bluetooth','bluetoothLEPiconetTutorial')">Create, Configure, and Simulate Bluetooth LE Network</a>.
%
%   Example 2: Create, Configure, and Simulate Bluetooth LE Broadcast Audio Network
%   <a
%   href="matlab:helpview('bluetooth','bluetoothLEBroadcastAudioNetworkTutorial')">Create, Configure, and Simulate Bluetooth LE Broadcast Audio Network</a>.
%
%   Example 3: Create, Configure, and Simulate Bluetooth Mesh Network
%   <a
%   href="matlab:helpview('bluetooth','bluetoothLEMeshNetworkTutorial')">Create, Configure, and Simulate Bluetooth Mesh Network</a>.
%
%   Example 4: Establish Friendship Between Friend Node and LPN in Bluetooth Mesh Network
%   <a
%   href="matlab:helpview('bluetooth','bluetoothLEMeshFriendshipTutorial')">Establish Friendship Between Friend Node and LPN in Bluetooth Mesh Network</a>.
%
%   See also bluetoothLEBIGConfig, bluetoothMeshProfileConfig,
%   bluetoothMeshFriendshipConfig, bluetoothLEConnectionConfig,
%   bluetoothLECISConfig, bluetoothLEPeriodicAdvConfig.

%   Copyright 2021-2024 The MathWorks, Inc.

properties % Configuration parameters
    %TransmitterPower Signal transmission power in dBm
    %   Specify the transmit power as a scalar in the range [-20, 20].
    %   Units are in dBm. This value specifies the average power that the
    %   transmitter applies on the signal before sending it to the antenna.
    %   The default value is 20 dBm.
    TransmitterPower (1,1) {mustBeNumeric,...
        mustBeInRange(TransmitterPower,-20,20)} = 20

    %TransmitterGain Transmitter antenna gain in dB
    %   Specify the transmitter antenna gain as a finite numeric scalar.
    %   Units are in dB. The default value is 0 dB.
    TransmitterGain (1,1) {mustBeNumeric,mustBeFinite} = 0

    %ReceiverRange Packet reception range of the node in meters
    %   Specify this property as a finite positive scalar. Units are in
    %   meters. If an incoming signal is received from a node present
    %   beyond this value,the node drops this signal. Set this property to
    %   reduce the processing complexity of the simulation. The default
    %   value is 100 meters.
    ReceiverRange (1,1) {mustBePositive,mustBeFinite} = 100

    % ReceiverGain Receiver antenna gain in dB
    %   Specify the receiver antenna gain as a finite numeric scalar. Units
    %   are in dB. The default value is 0 dB.
    ReceiverGain (1,1) {mustBeNumeric,mustBeFinite} = 0

    %ReceiverSensitivity Receiver sensitivity in dBm
    %   Specify the receiver sensitivity as a finite numeric scalar. Units
    %   are in dBm. This property sets the minimum reception power to
    %   detect the incoming signal. If the received power of an incoming
    %   signal is below this value, the node considers the signal as
    %   invalid. The default value is -100 dBm.
    ReceiverSensitivity (1,1) {mustBeNumeric,mustBeFinite} = -100

    %NoiseFigure Noise figure in dB
    %   Specify the noise figure as a nonnegative finite scalar. Units are
    %   in dB. The object uses this value to apply thermal noise on the
    %   received signal. The default value is 0 dB.
    NoiseFigure (1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite} = 0

    %AdvertisingInterval Advertising interval in seconds
    %   Specify advertising interval as a scalar in the range [0.02,
    %   10485.759375]. Units are in seconds. This value specifies the
    %   interval of an advertising event during which the transmission of
    %   advertising packets occurs. Set this value as an integer multiple
    %   of 0.625 milliseconds. The default value is 0.02 seconds.
    AdvertisingInterval = 0.02

    %RandomAdvertising Random advertising channel selection
    %   Specify the random advertising channel selection flag as 1 (true)
    %   or 0 (false). If you set this value to 1 (true), the object models
    %   the random selection of advertising channels. If you set this value
    %   to 0 (false), the object disables the random selection of
    %   advertising channels. The default value is 0 (false).
    RandomAdvertising (1,1) logical = false

    %ScanInterval Scan interval in seconds
    %   Specify scan interval as a scalar in the range [0.0025, 40.960].
    %   Units are in seconds. This value specifies the interval in which
    %   the node listens for the advertising packets. Set this value as an
    %   integer multiple of 0.625 milliseconds. The default value is 0.005
    %   seconds.
    ScanInterval = 0.005

    %MeshConfig Bluetooth mesh configuration object for
    %"broadcaster-observer" role
    %   Specify mesh config as an object of type <a
    %   href="matlab:help('bluetoothMeshProfileConfig')">bluetoothMeshProfileConfig</a>.
    %   This value is used when the <a
    %   href="matlab:help('bluetoothLENode.Role')">Role</a> is set to
    %   "broadcaster-observer". The default value is an object of type
    %   "bluetoothMeshProfileConfig" with all properties set to their
    %   default values.
    MeshConfig (1,1) bluetoothMeshProfileConfig = bluetoothMeshProfileConfig

    %InterferenceModeling Type of interference modeling
    %    Specify the type of interference modeling as
    %    "overlapping-adjacent-channel" or "non-overlapping-adjacent-channel".
    %    If you set this property to "overlapping-adjacent-channel", the object
    %    considers signals overlapping in time and frequency, to be
    %    interference. If you set this property to
    %    "non-overlapping-adjacent-channel", the object considers all the
    %    signals overlapping in time and with frequency in the range [f1-<a
    %    href="matlab:help('bluetoothLENode.MaxInterferenceOffset')">MaxInterferenceOffset</a>, f2+<a
    %    href="matlab:help('bluetoothLENode.MaxInterferenceOffset')">MaxInterferenceOffset</a>],
    %    to be interference. f1 and f2 are the starting and ending frequencies
    %    of SOI, respectively. The default value is
    %    "overlapping-adjacent-channel".
    InterferenceModeling = "overlapping-adjacent-channel"

    %MaxInterferenceOffset Maximum frequency offset to determine the
    %interfering signal
    %   Specify the maximum interference offset as a nonnegative scalar. Units
    %   are in Hz. This property specifies the offset between the edge of the
    %   SOI frequency and the edge of the interfering signal. This property
    %   applies only when the <a
    %   href="matlab:help('bluetoothLENode.InterferenceModeling')">InterferenceModeling</a>
    %   property is set to "non-overlapping-adjacent-channel". If you specify
    %   this property as Inf, the object considers all the signals that overlap
    %   in time, regardless of their frequency, to be interference. If you
    %   specify this property as a finite nonnegative scalar, the object
    %   considers all the signals overlapping in time and with frequency in the
    %   range [f1-MaxInterferenceOffset, f2+MaxInterferenceOffset], to be
    %   interference. The default value is 100e6.
    MaxInterferenceOffset (1,1) {mustBeNumeric,mustBeNonnegative} = 100e6
end

properties (Dependent)
    %InterferenceFidelity Fidelity level to model interference
    % Specify the fidelity level to model interference as 0 (false) or 1(true).
    % If you set this value to 0 (false), the object considers signals
    % overlapping in time and frequency as interference (co-channel
    % interference). If you set this value to 1 (true), the object considers
    % all the signals overlapping in time as interference, regardless of the
    % frequency. The default value is 0.
    InterferenceFidelity
end

properties (Constant,Hidden)
    % Allowed role values
    Role_Values = ["central","peripheral","isochronous-broadcaster",...
        "synchronized-receiver","broadcaster-observer","broadcaster","observer"]

    %ReceiveBufferSize Maximum number of frames that can be stored at the
    %receiver buffer of the node
    ReceiveBufferSize = 10

    %InterferenceModeling_Values List of interference modeling types
    InterferenceModeling_Values = ["overlapping-adjacent-channel","non-overlapping-adjacent-channel"]
end

properties (SetAccess=protected)
    %Role Role of the Bluetooth LE node. The role is specified as any one of
    %"central", "peripheral", "isochronous-broadcaster",
    %"synchronized-receiver" or "broadcaster-observer". If you do not specify
    %this value in the constructor, the default role of the node is
    %"peripheral".
    Role = "peripheral"

    %ConnectionConfig Connection configuration object for "central" and
    %"peripheral" roles. Specify this property as an object or vector of
    %objects of type <a
    %href="matlab:help('bluetoothLEConnectionConfig')">bluetoothLEConnectionConfig</a>.
    ConnectionConfig = bluetoothLEConnectionConfig

    %PeriodicAdvConfig Periodic advertisement configuration object for
    %"broadcaster" and "observer" roles. Specify this property as an object or
    %an vector of objects of type <a
    %href="matlab:help('bluetoothLEPeriodicAdvConfig')">bluetoothLEPeriodicAdvConfig</a>.
    %This property specifies the synchronization information shared between the
    %Broadcaster and Observer as part of Periodic advertisements establishment
    %process.
    PeriodicAdvConfig = bluetoothLEPeriodicAdvConfig

    %CISConfig Connected isochronous stream (CIS) connection configuration
    %object for "central" and "peripheral" roles. Specify this property as an
    %object or an vector of objects of type <a
    %href="matlab:help('bluetoothLECISConfig')">bluetoothLECISConfig</a>.
    CISConfig = bluetoothLECISConfig

    %PeripheralCount Number of peripherals associated with the central.
    %This property is applicable only when the Role is "central". This
    %property is specified as a scalar nonnegative integer.
    PeripheralCount = 0
    
    %BIGConfig BIG configuration object for "isochronous-broadcaster" and
    %"synchronized-receiver" roles. Specify this property as an object of
    %type <a
    %href="matlab:help('bluetoothLEBIGConfig')">bluetoothLEBIGConfig</a>.
    BIGConfig = bluetoothLEBIGConfig

    %FriendshipConfig Friendship configuration object for a Friend and low
    %power node. Specify this property as an object of type <a
    %href="matlab:help('bluetoothMeshFriendshipConfig')">bluetoothMeshFriendshipConfig</a>.
    FriendshipConfig = bluetoothMeshFriendshipConfig

    %TransmitBuffer Buffer containing the data to be transmitted from the
    %node. Specify the property as a structure of the format <a
    %href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.
    TransmitBuffer
end

properties (SetAccess=protected,GetAccess=public,Hidden)
    %NumConnections Specifies the number of active connections in this node.
    %This property is applicable only when you set the "Role" property to
    %"central" or "peripheral".
    NumConnections = 0

    %NumPeriodicAdvs Specifies the number of periodic advertising trains
    %associated to this node. This property is applicable only when you set the
    %"Role" property to "broadcaster" or "observer".
    NumPeriodicAdvs = 0

    %NumCISConnections Specifies the number of active CIS connections in this
    %node. This property is applicable only when you set the "Role" property to
    %"central" or "peripheral" with a configured CIS connection.
    NumCISConnections = 0

    %BIGPresent Specifies if there is a BIG connection in this node. This
    %property is applicable only when you sent the "Role" property to
    %"isochronous-broadcaster" or "synchronized-receiver".
    BIGPresent = false

    %CISCount Specifies the number of CIS connections in this node. This
    %property is applicable only for central and peripheral roles with a
    %configured CIS connection. If the device is operating as a central role,
    %this property will be a vector with a size of NumConnections. Each index
    %within the vector will represent the number of CIS connections associated
    %with a specific peripheral device.
    CISCount

    %CurrentTime Current time of the simulation in seconds.
    CurrentTime

    %FriendshipEstablished Specifies whether friendship is already
    %established for this node
    FriendshipEstablished (1,1) logical = false
end

properties (Hidden)
    %PHYReceiver PHY receiver object
    PHYReceiver

    %PreemptiveScanning Preempt link layer scanning
    %   Specify this property as 1 (true) or 0 (false). If you set this value
    %   to 1 (true), the node pauses link layer scanning and switches to
    %   advertising when any packet arrives from higher layers while in the
    %   scanning state. The default value is 0 (false).
    PreemptiveScanning (1,1) logical = false

    % Invoke channel if signal lies in the 2.4 GHz band. The 2.4 GHz band
    % for Bluetooth LE starts at 2.4e9 Hz and ends at 2.4835e9 Hz.
    BluetoothLEStartBand = 2.4e9 % in Hz
    BluetoothLEEndBand = 2.4835e9 % in Hz

    %ConnectedNodeIDs Vector of node IDs which are associated with this
    %node
    ConnectedNodeIDs
end

properties (Access=protected)
    %pLinkLayer Link layer object based on the specified role
    pLinkLayer

    %pPHYTransmitter PHY transmitter object
    pPHYTransmitter

    %pMesh Bluetooth mesh profile object
    pMesh

    %pTrafficManager Traffic manager object
    pTrafficManager

    %pCurrentTimeInMicroseconds Current time in microseconds
    pCurrentTimeInMicroseconds

    %pConnectedNodes Vector of node names which are associated with this
    %node
    pConnectedNodes = ""

    %pRxInfo Structure containing the receiver information that needs to be
    %passed to the channel
    pRxInfo

    %pIsInitialized Flag to check whether the node is initialized or not
    pIsInitialized = false

    %pAppStatistics Statistics captured at the application on top of the link
    %layer
    pAppStatistics = struct("DestinationNode", blanks(0), ...
        "TransmittedPackets", 0, ...
        "TransmittedBytes", 0, ...
        "ReceivedPackets", 0, ...
        "ReceivedBytes", 0, ...
        "AggregatePacketLatency", 0, ...
        "AveragePacketLatency", 0)

    %pMeshAppStatistics Statistics captured at the application on top of the
    %mesh profile
    pMeshAppStatistics = struct( ...
        "SourceAddress", "0000", ...
        "DestinationAddress", "0000", ...
        "TransmittedPackets", 0, ...
        "TransmittedBytes", 0, ...
        "ReceivedPackets", 0, ...
        "ReceivedBytes", 0, ...
        "AggregatePacketLatency", 0, ...
        "AveragePacketLatency", 0);

    %pMeshAppStatisticsList Vector of pMeshAppStatistics storing mesh
    %application statistics
    pMeshAppStatisticsList

    %pMeshAppSize Size of pMeshAppStatisticsList
    pMeshAppSize = 0

    %pAppDataReceived Structure containing metadata for application data
    %reception event
    pAppDataReceived = struct("NodeName",blanks(0),...
        "NodeID",[],...
        "CurrentTime",[],...
        "ReceivedData",[],...
        "SourceNode",blanks(0))

    %pMeshAppDataReceived Structure containing metadata for mesh
    %application data reception event
    pMeshAppDataReceived = struct("NodeName",blanks(0),...
        "NodeID",[],...
        "CurrentTime",[],...
        "Message",[],...
        "SourceAddress",blanks(0),...
        "DestinationAddress",blanks(0))

    %pMaxInterferenceOffsetVal Maximum interference offset value based on the
    %InterferenceModeling and MaxInterferenceOffset property
    pMaxInterferenceOffsetVal

    %pFileName Current feature file name
    pFileName = mfilename
end

events
    %PacketTransmissionStarted is triggered when the node starts
    %transmitting a packet. PacketTransmissionStarted passes the event
    %notification along with this structure to the registered callback:
    %   NodeName         - Node name. The field value is a string scalar.
    %   NodeID           - Unique node identifier. The field value is a
    %                      scalar positive integer.
    %   CurrentTime      - Current simulation time in seconds. The field
    %                      value is a nonnegative numeric scalar.
    %   PDU              - PDU bits to be transmitted. The field value is a
    %                      binary column vector.
    %   AccessAddress    - Access address of the packet. The field value is
    %                      a string scalar representing 4-octet hexadecimal
    %                      number.
    %   ChannelIndex     - Channel index for transmission. The field is an
    %                      integer in the range [0, 39].
    %   PHYMode          - PHY transmission mode. The field value is one of
    %                      "LE1M", "LE2M", "LE500K" or "LE125K"
    %   TransmittedPower - Transmit power in dBm. The field value is a
    %                      scalar value.
    %   PacketDuration   - Packet duration in seconds. The field value is a 
    %                      positive numeric scalar.
    PacketTransmissionStarted

    %PacketReceptionEnded is triggered when a packet reception ends.
    %PacketReceptionEnded passes the event notification along with this
    %structure to the registered callback:
    %   NodeName       - Node name. The field value is a string scalar.
    %   NodeID         - Unique node identifier. The field value is a
    %                    scalar positive integer.
    %   CurrentTime    - Current simulation time in seconds. The field
    %                    value is a nonnegative numeric scalar.
    %   SourceNode     - Name of the source node. The field value is a
    %                    string scalar.
    %   SourceID       - Node ID of the source. The field value is a scalar
    %                    positive integer.
    %   SuccessStatus  - Flag indicating the success status of packet.
    %                    The field value is a logical scalar.
    %   PDU            - PDU bits to be received. The field value is a
    %                    binary column vector.
    %   AccessAddress  - Access address of the packet. The field value is a
    %                    string scalar representing 4-octet hexadecimal
    %                    number.
    %   ChannelIndex   - Channel index for reception. The field value is an
    %                    integer in the range [0, 39].
    %   PHYMode        - PHY reception mode. The field value is one of
    %                    "LE1M", "LE2M", "LE500K" or "LE125K".
    %   PacketDuration - Duration of the packet received. The field value is a
    %                    numeric positive scalar value or [].
    %   ReceivedPower  - Received power in dBm. the field value is a scalar
    %                    value.
    %   SINR           - Signal-to-interference plus noise ratio in dB. The
    %                    field value is a scalar.
    PacketReceptionEnded

    %ChannelMapUpdated is triggered when the node starts using the updated
    %channel map. ChannelMapUpdated passes the event notification along
    %with this structure to the registered callback:
    %   NodeName           - Node name. The field value is a string scalar.
    %   NodeID             - Unique node identifier. The field value is a
    %                        scalar positive integer.
    %   CurrentTime        - Current simulation time in seconds. The field
    %                        value is a nonnegative numeric scalar.
    %   PeerNode           - Name of the peer node. The field value is a
    %                        string scalar.
    %   PeerID             - Identifier of the peer node. The field value
    %                        is a scalar positive integer.
    %   UpdatedChannelList - List of good channels. The field value is a
    %                        vector of integers in the range [0, 36].
    ChannelMapUpdated

    %AppDataReceived is triggered when there is data for application
    %from the node. AppDataReceived passes the event notification
    %along with this structure to the registered callback:
    %   NodeName       - Node name. The field value is a string scalar.
    %   NodeID         - Unique node identifier. The field value is a
    %                    scalar positive integer.
    %   CurrentTime    - Current simulation time in seconds. The field
    %                    value is a nonnegative numeric scalar.
    %   SourceNode     - Name of the source node. The field value is a
    %                    string scalar.
    %   ReceivedData   - Received application data in decimal bytes. The
    %                    field value is a vector of integers in the range
    %                    [0, 255].
    AppDataReceived
    
    %MeshAppDataReceived is triggered when application data received for a
    %mesh node. MeshAppDataReceived passes the event notification along
    %with this structure to the registered callback:
    %   NodeName           - Name of the receiver node. The field value is
    %                        a string scalar.
    %   NodeID             - Unique identifier of the receiver node. The
    %                        field value is a scalar positive integer.
    %   CurrentTime        - Current simulation time in seconds. The field
    %                        value is a nonnegative numeric scalar.
    %   Message            - Received access message. The field value is a
    %                        vector of integers in the range [0, 255].
    %   SourceAddress      - Source address of the message. The field value
    %                        is a string scalar representing 2-octet
    %                        hexadecimal number.
    %   DestinationAddress - Destination address of the message. The field
    %                        value is a string scalar representing 2-octet
    %                        hexadecimal number.
    MeshAppDataReceived

    %ConnectionEventEnded is triggered at the end of each connection event.
    %ConnectionEventEnded passes the event notification along with this
    %structure to the registered callback:
    %   NodeName           - Node name. The field value is a string scalar.
    %   NodeID             - Unique node identifier. The field value is a
    %                        scalar positive integer.
    %   CurrentTime        - Current simulation time in seconds. The field
    %                        value is a nonnegative numeric scalar.
    %   Counter            - Current connection event counter. The field
    %                        value is a scalar integer in the range [0,
    %                        65535].
    %   TransmittedPackets - Number of transmitted packets in the
    %                        connection event. The field value is a scalar
    %                        nonnegative integer.
    %   ReceivedPackets    - Number of received packets in the connection
    %                        event. The field value is a scalar nonnegative
    %                        integer.
    %   CRCFailedPackets   - Number of received packets with CRC failure.
    %                        The field value is a scalar nonnegative
    %                        integer.
    ConnectionEventEnded
end

events (Hidden)
    %SleepStateTransition is triggered at the start or end of each sleep state.
    %SleepStateTransition passes the event notification along with this
    %structure to the registered callback:
    %   NodeName           - Node name. The field value is a string scalar.
    %   NodeID             - Unique node identifier. The field value is a
    %                        scalar positive integer.
    %   CurrentTime        - Current simulation time in seconds. The field
    %                        value is a nonnegative numeric scalar.
    %   SleepDuration      - Duration of the sleep state in seconds. The field
    %                        value is a numeric scalar.
    %   TransitionType     - Type of the state transition, indicating entry or
    %                        exit of the sleep state. The field value is a
    %                        logical scalar. 0 (false) indicates entry to sleep
    %                        state. 1 (true) indicates exit of sleep state. If
    %                        the event is triggered at the exit of sleep state,
    %                        SleepDuration field indicates how long the node
    %                        was in sleep state from the CurrentTime field. If
    %                        the event is triggered at the entry of sleep
    %                        state, SleepDuration field indicates how long the
    %                        node is going to be in sleep state from the
    %                        current time.
    SleepStateTransition
end

methods
    % Constructor
    function bluetoothLENodeObjs = bluetoothLENode(varargin)

        % Get the name value pairs and the role of the node
        nvPairs = {};
        if nargin>0
            % If arguments are specified, check if the first argument is a valid role
            % or NV pair
            firstArg = varargin{1};
            if mod(nargin,2)==0
                % If arguments are specified as NV pairs, check that first argument is not
                % a role value
                if any(strcmp(firstArg,bluetoothLENode.Role_Values))
                    error(message("MATLAB:system:invalidPVPairs"));
                end
                nvPairs = varargin;
            else
                % Validate the role
                bluetoothLENodeObjs.Role = validatestring(firstArg,bluetoothLENode.Role_Values,bluetoothLENodeObjs.pFileName,"role",1);
                nvPairs = varargin(2:end);
            end
        end
        role = bluetoothLENodeObjs.Role;

        numNodes = 1;
        % Updated the properties based on the Name-Value pair
        if nargin > 1
            % Identify number of nodes user intends to create based on
            % Position value
            for idx = 1:2:numel(nvPairs)
                % Search the presence of 'Position' N-V pair argument
                if strcmp(nvPairs{idx},"Position")
                    validateattributes(nvPairs{idx+1},{'numeric'},{'nonempty','ncols',3,'finite'}, bluetoothLENodeObjs.pFileName,"Position");
                    positionValue = nvPairs{idx+1};
                    numNodes = size(nvPairs{idx+1},1);
                end
                % Search the presence of 'Name' N-V pair argument
                if strcmp(nvPairs{idx},"Name")
                    nameValue = string(nvPairs{idx+1});
                end
            end
        end

        % Create Bluetooth nodes
        bluetoothLENodeObjs = repmat(bluetoothLENodeObjs,1,numNodes);
        for idx=2:numNodes
            % To support vectorization when inheriting "bluetoothLENode", instantiate
            % class based on the object's existing class
            className = class(bluetoothLENodeObjs(1));
            classFunc = str2func(className);
            bluetoothLENodeObjs(idx) = classFunc(role);
        end

        % Set the configuration as per the N-V pairs        
        for idx=1:2:numel(nvPairs)
            name = nvPairs{idx};
            value = nvPairs{idx+1};
            if strcmp(name,"Position")
                % Set position for node(s)
                for objIdx = 1:numNodes
                    bluetoothLENodeObjs(objIdx).Position = positionValue(objIdx, :);
                end
            elseif strcmp(name,"Name")
                % Set name for node(s). If name is not supplied
                % for all nodes then leave the trailing nodes
                % with default names
                nameCount = min(numel(nameValue), numNodes);
                for objIdx=1:nameCount
                    bluetoothLENodeObjs(objIdx).Name = nameValue(objIdx);
                end
            else
                % Make all the nodes identical by setting same
                % value for all the configurable properties,
                % except position and name
                [bluetoothLENodeObjs.(char(name))] = deal(value);
            end
        end
        if numNodes>1 && strcmp(role,"broadcaster-observer")
            error(message("bluetooth:bluetoothLENode:MeshVectorizationNotSupported"));
        end

        for idx = 1:numNodes
            bluetoothLEObj = bluetoothLENodeObjs(idx);

            % Use weak-references for cross-linking handle objects
            objWeakRef = matlab.lang.WeakReference(bluetoothLEObj);

            % Create callback for event notification from internal layers to the node
            notificationFcn = @(eventName, eventData) objWeakRef.Handle.triggerEvent(eventName, eventData);
            
            % Initialize the internal modules
            appPacket = struct("ConnectionIndex",0,"SourceAddress","0000",...
                "DestinationAddress","0000","TTL",0,"CISID",[]);
            sendPacketFcn = @(packet) objWeakRef.Handle.pushUpperLayerData(packet);
            bluetoothLEObj.pTrafficManager = wirelessnetwork.internal.trafficManager(bluetoothLEObj.ID,sendPacketFcn, ...
                notificationFcn,PacketContext=appPacket,DataAbstraction=false);
            if any(strcmp(role,["central", "peripheral"]))
                bluetoothLEObj.pLinkLayer = ble.internal.linkLayerConnections(notificationFcn,Role=role);
            elseif any(strcmp(role,["isochronous-broadcaster", "synchronized-receiver"]))
                bluetoothLEObj.pLinkLayer = ble.internal.linkLayerBroadcastIsochronousGroup(NotificationFcn=notificationFcn);
            elseif any(strcmp(role,["broadcaster-observer","broadcaster","observer"]))
                bluetoothLEObj.pLinkLayer = StatefulGAPBearer(notificationFcn,Role=role);
                if strcmp(role,"broadcaster-observer")
                    bluetoothLEObj.pMesh = ble.internal.meshProfile;
                end
            end
            bluetoothLEObj.pPHYTransmitter = ble.internal.phyTransmitter(NotificationFcn=notificationFcn);
            bluetoothLEObj.PHYReceiver = ble.internal.phyReceiver;

            % Initialize receiver information
            bluetoothLEObj.pRxInfo = struct("ID",bluetoothLEObj.ID,"Position",[0 0 0],"Velocity",[0 0 0],"NumReceiveAntennas",1);
            bluetoothLEObj.ReceiveFrequency = 2440e6;
            bluetoothLEObj.ReceiveBandwidth = 80e6;
        end
    end

    function set.InterferenceFidelity(~,~)

        error(message("bluetooth:bleShared:InterferenceFidelityDeprecation"));
    end

    function set.InterferenceModeling(obj,value)

        value = validatestring(value,obj.InterferenceModeling_Values,obj.pFileName,"InterferenceModeling");
        obj.InterferenceModeling = string(value);
    end

    function value = get.InterferenceFidelity(obj)

        if strcmp(obj.InterferenceModeling,obj.InterferenceModeling_Values(1))
            value = 0; % overlapping-adjacent-channel
        else
            value = 1; % non-overlapping-adjacent-channel
        end
    end

    % Set advertising interval
    function set.AdvertisingInterval(obj,value)
        validateattributes(value,{'numeric'},{'scalar','>=',20e-3,...
            '<=',10485.759375},obj.pFileName,"AdvertisingInterval");
        if mod(value,0.625e-3)~=0
            error(message("bluetooth:bluetoothLENode:InvalidAdvertisingInterval",num2str(value)));
        end
        obj.AdvertisingInterval = value; % in seconds
    end

    % Set scan interval
    function set.ScanInterval(obj,value)
        validateattributes(value,{'numeric'},{'scalar','>=',2.5e-3,...
            '<=',40.960},obj.pFileName,"ScanInterval");
        if mod(value,0.625e-3)~=0
            error(message("bluetooth:bluetoothLENode:InvalidScanInterval",num2str(value)));
        end
        obj.ScanInterval = value; % in seconds
    end
    
    % Set mesh configuration object
    function set.MeshConfig(obj,value)
        validateattributes(value,{'bluetoothMeshProfileConfig'},{'scalar'},...
            obj.pFileName,"MeshConfig");
        if ~strcmp(obj.Role,"broadcaster-observer") %#ok<*MCSUP>
            error(message("bluetooth:bluetoothLENode:InvalidRoleMeshConfig"));
        end
        obj.MeshConfig = value;
    end

    % Get the number of peripherals associated with central node
    function value = get.PeripheralCount(obj)
        value = obj.NumConnections;
    end

    % Get the packet from node transmit buffer
    function value = get.TransmitBuffer(obj)
        value = pullTransmittedData(obj);
        if isempty(value)
            value = wirelessnetwork.internal.wirelessPacket;
        end
    end
end

methods (Access=protected)
    function flag = isInactiveProperty(obj,prop)
        flag = false;
        if any(strcmp(prop,["ConnectionConfig","CISConfig"]))
            % Connection configuration is applicable only for central and
            % peripheral roles
            flag = ~any(strcmp(obj.Role,{'central','peripheral'}));
        elseif strcmp(prop,"BIGConfig")
            % BIG configuration is applicable only for isochronous
            % broadcaster and synchronized-receiver roles
            flag = ~any(strcmp(obj.Role,{'isochronous-broadcaster','synchronized-receiver'}));
        elseif strcmp(prop,"PeripheralCount")
            % Peripheral count is applicable only for central role
            flag = ~strcmp(obj.Role,"central");
        elseif strcmp(prop,"AdvertisingInterval")
            % Advertising interval applicable only for broadcaster-observer and broadcaster role
            flag = ~any(strcmp(obj.Role,{'broadcaster-observer','broadcaster'}));
        elseif strcmp(prop,"ScanInterval")
            % Scan interval applicable only for broadcaster-observer and observer role
            flag = ~any(strcmp(obj.Role,{'broadcaster-observer','observer'}));
        elseif strcmp(prop,"RandomAdvertising")
            % Random advertising applicable only for broadcaster-observer, broadcaster
            % and observer role
            flag = ~any(strcmp(obj.Role,{'broadcaster-observer','broadcaster','observer'}));
        elseif any(strcmp(prop,["MeshConfig","FriendshipConfig"]))
            % Mesh and friendship configuation applicable for broadcaster and observer
            % roles
            flag = ~strcmp(obj.Role,"broadcaster-observer");
        elseif strcmp(prop,"PeriodicAdvConfig")
            % Periodic configuration applicable only for broadcaster-observer and
            % observer role
            flag = ~any(strcmp(obj.Role,{'broadcaster','observer'}));
        elseif strcmp(prop,"MaxInterferenceOffset")
            % Max interference offset applicable only when interference modeling is set
            % to overlapping adjacent channel
            flag = strcmp(obj.InterferenceModeling,"overlapping-adjacent-channel");
        end
    end
end

methods
    function addTrafficSource(obj,trafficSource,varargin)
        %addTrafficSource Add data traffic source to Bluetooth LE node
        %
        %   addTrafficSource(OBJ, TRAFFICSOURCE) adds a data traffic source object
        %   to the node. The traffic source, TRAFFICSOURCE, is an object of type <a
        %   href="matlab:help('networkTrafficOnOff')">networkTrafficOnOff</a>.
        %   To enable this syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to
        %   "isochronous-broadcaster" or "broadcaster".
        %
        %   addTrafficSource(OBJ, TRAFFICSOURCE, DestinationNode=destinationNode)
        %   adds a data traffic source object to the node for pumping traffic to
        %   the specified destination, DestinationNode. To enable this syntax, set
        %   the <a href="matlab:help('bluetoothLENode.Role')">Role</a> property of <a href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to either "central" or "peripheral".
        %
        %   The "DestinationNode" argument specifies the destination node. Specify
        %   this input as a character vector or string scalar denoting the name of
        %   the destination. You can also specify this input as an object of type
        %   <a href="matlab:help('bluetoothLENode')">bluetoothLENode</a> with the <a href="matlab:help('bluetoothLENode.Role')">Role</a> property set to either "central" or "peripheral".
        %
        %   addTrafficSource(OBJ, TRAFFICSOURCE, DestinationNode=destinationNode,
        %   CISConfig=cisConfig) adds a data traffic source object, TRAFFICSOURCE,
        %   to the node for pumping traffic to the specified connected isochronous
        %   stream (CIS) connection, CISConfig, in the destination node,
        %   DestinationNode. To enable this syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>
        %   object to "central" or "peripheral".
        %
        %   The "CISConfig" input argument specifies the CIS connection in the
        %   destination node. Specify this input as an object of type <a
        %   href="matlab:help('bluetoothLECISConfig')">bluetoothLECISConfig</a>.
        %   When a CIS connection is established between the Central and Peripheral
        %   nodes, the <a href="matlab:help('bluetoothLEConnectionConfig.configureConnection')">configureConnection</a> object function returns the CISConfig value.
        %   Use this output configuration object as an input to this object function.
        %
        %   addTrafficSource(OBJ, TRAFFICSOURCE, DestinationAddress=dstAddress,
        %   SourceAddress=srcAddress, varargin) adds a data traffic source object
        %   to the node for pumping the traffic between the source and the
        %   destination. To enable this syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to
        %   "broadcaster-observer".
        %
        %   addTrafficSource(OBJ, TRAFFICSOURCE, DestinationAddress=dstAddress,
        %   SourceAddress=srcAddress, TTL=ttl) adds a data traffic source object to
        %   the node for pumping the traffic between source and destination with
        %   the specified TTL (time-to-live) value. To enable this syntax, set the
        %   <a href="matlab:help('bluetoothLENode.Role')">Role</a> property of <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to
        %   "broadcaster-observer".
        %
        %   The "DestinationAddress" argument specifies the destination address of
        %   this message. Specify the destination address value as 4-element
        %   character vector or string scalar denoting a 2-octet hexadecimal
        %   address. The destination address can be a valid element address in the
        %   mesh network or a group address.
        %
        %   The "SourceAddress" argument specifies the source address of this
        %   message. Specify the source address value as 4-element character vector
        %   or string scalar denoting a 2-octet hexadecimal unicast address. The
        %   source address must be one of the element address in the mesh node.
        %
        %   "TTL" argument is an optional input if the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object is set
        %   to "broadcaster-observer". This value specifies time-to-live value for
        %   messages between the specified source and destination mesh elements.
        %   Specify the TTL value as an integer in the range [0, 127]. By default,
        %   this object function uses the TTL value specified by the <a
        %   href="matlab:help('bluetoothLENode.MeshConfig')">MeshConfig</a> object.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   TRAFFICSOURCE is an On-Off application traffic pattern object of type
        %   <a href="matlab:help('networkTrafficOnOff')">networkTrafficOnOff</a>. If you add the traffic source, the <a
        %   href="matlab:help('networkTrafficOnOff.GeneratePacket')">GeneratePacket</a>
        %   property of the traffic source object is not applicable because the
        %   Bluetooth LE node always generates the packets.
        %
        %   For more information, see <a
        %   href="matlab:helpview('bluetooth','bluetoothLEaddTrafficSourceExample')"
        %   >Create, Configure, and Simulate Bluetooth LE Network</a> example.

        % Validate object is scalar
        validateattributes(obj, {'bluetoothLENode'}, {'scalar'}, mfilename, '', 1);

        if ~isempty(obj.CurrentTime)
            error(message("bluetooth:bleShared:NotSupportedOperation","addTrafficSource"));
        end

        % Validate the name-value arguments
        upperLayerDataInfo = validateUpperLayerMetadata(obj,trafficSource,varargin{:});

        % Add the traffic source to the application manager
        addTrafficSource(obj.pTrafficManager,trafficSource,upperLayerDataInfo);
    end

    function status = updateChannelList(obj,newUsedChannelsList,varargin)
        %updateChannelList Provide updated channel list to Bluetooth LE node
        %
        %   STATUS = updateChannelList(OBJ, NEWUSEDCHANNELSLIST) updates
        %   the channel map by providing a new list of used channels,
        %   NEWUSEDCHANNELSLIST, to the node and returns the status,
        %   STATUS, indicating whether the node accepted the new channel
        %   list or not. To enable this syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to
        %   "isochronous-broadcaster" or "broadcaster".
        %
        %   STATUS is a logical scalar value set as true when the link
        %   layer accepts the new channel list.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   NEWUSEDCHANNELSLIST is the list of good (used) channels,
        %   specified as an integer vector with element values in the range
        %   [0, 36].
        %
        %   STATUS = updateChannelList(OBJ, NEWUSEDCHANNELSLIST,
        %   DestinationNode=destinationNode) updates the channel map for
        %   the specified destination, DestinationNode. To enable this
        %   syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of
        %   <a href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to "central".
        %
        %   The "DestinationNode" argument is a mandatory input, specifying
        %   the destination node. Specify this input as a character vector
        %   or string scalar specifying the name of the destination. You
        %   can also specify this input as an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a> with
        %   the <a href="matlab:help('bluetoothLENode.Role')">Role</a> property set to either "central" or "peripheral".
        %
        %   For more information, see <a href="matlab:helpview('bluetooth','bluetoothLEupdateChannelListExample')">Classify Channels and Update Channel Map in Bluetooth LE Network</a> example.

        % Validate object is scalar
        validateattributes(obj, {'bluetoothLENode'}, {'scalar'}, mfilename, '', 1);

        if ~obj.pIsInitialized
            error(message("bluetooth:bluetoothLENode:NodeNotInitialized"));
        end
        status = false;
        % Validate the roles and the respective NV-pairs
        % Update channel list is not applicable for synchronized receiver,
        % peripheral, observer, or broadcaster-observer roles
        role = obj.Role;
        if any(strcmp(role,["synchronized-receiver","peripheral","broadcaster-observer","observer"]))
            error(message("bluetooth:bluetoothLENode:UpdateChannelListNotApplicable",obj.Role));
        elseif strcmp(role,"isochronous-broadcaster") % No NV-pairs are applicable for "isochronous-broadcaster" role
            narginchk(2,2);
            status = updateChannelList(obj.pLinkLayer,newUsedChannelsList);
        elseif strcmp(role,"broadcaster") % No NV-pairs are applicable for "broadcaster" role
            if obj.NumPeriodicAdvs==0
                error(message("bluetooth:bluetoothLENode:UpdateChannelListNotApplicableLegacyAdv"));
            end
            narginchk(2,2);
            status = updateChannelList(obj.pLinkLayer,newUsedChannelsList);
        elseif strcmp(role,"central") % DestinationNodeID is applicable for central role
            narginchk(4,4);
            for i = 1:2:nargin-2 % Apply name-value arguments
                validatestring(varargin{i},{'DestinationNode'},...
                    obj.pFileName,"name-value-arguments");
                validateattributes(varargin{i+1},{'char','string','bluetoothLENode'},...
                    {'row'},obj.pFileName,"DestinationNode");
                destinationNode = varargin{i+1};
                if ischar(destinationNode) || isstring(destinationNode)
                    connectionIndex = find(strcmpi(destinationNode,obj.pConnectedNodes));
                else
                    connectionIndex = find(strcmpi(destinationNode.Name,obj.pConnectedNodes));
                end
                status = updateChannelList(obj.pLinkLayer,newUsedChannelsList,connectionIndex);
            end
        end
    end

    function nodeStatistics = statistics(obj)
        %statistics Get the statistics of Bluetooth LE node
        %
        %   NODESTATISTICS = statistics(OBJ) returns the Bluetooth LE node
        %   statistics. You can fetch statistics for multiple Bluetooth LE nodes at
        %   once by calling this function on a vector of Bluetooth LE nodes.
        %   NODESTATISTICS is a vector of statistics and an element at index 'idx'
        %   contains the statistics of Bluetooth LE node at index 'idx' of
        %   Bluetooth node vector, OBJ.
        %
        %   NODESTATISTICS is a structure that stores the statistics of the node.
        %   If you specify the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> at a node as
        %   "central" or "peripheral", then this value contains statistics related
        %   to Bluetooth low energy (LE) node with connection events or CIS events
        %   (If enabled). If you specify the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> at a node as
        %   "isochronous-broadcaster" or "synchronized-receiver", then this value
        %   contains statistics related to Bluetooth LE node with broadcast
        %   isochronous group (BIG) events. If you specify the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> at a node as
        %   "broadcaster-observer", then this value contains statistics related to
        %   Bluetooth LE mesh node. If you specify the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> at a node as
        %   "broadcaster" or "observer", then this value contains statistics
        %   related to the Bluetooth LE node with legacy advertisements. However,
        %   if you specify periodic advertising configuration, then this value
        %   contains statistics related to the Bluetooth LE node with periodic
        %   advertisements. When the statistics for multiple Bluetooth nodes
        %   are fetched at once, NODESTATISTICS is a row vector of structure.
        %   For more information, see <a
        %   href="matlab:helpview('bluetooth','bluetoothLENodeStatistics')">Bluetooth
        %   LE Node Statistics</a>.
        %
        %   OBJ is an object or a vector of objects of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.

        arguments
            obj (1,:)
        end

        nodeStatistics = repmat(struct,1,numel(obj));
        for nodeIdx = 1:numel(obj)
            node = obj(nodeIdx);
            % Initialize the node
            if ~node.pIsInitialized
                init(node);
            end

            nodeStatistics(nodeIdx).Name = node.Name;
            nodeStatistics(nodeIdx).ID = node.ID;
            phyTx = node.pPHYTransmitter;
            phyRx = node.PHYReceiver;

            role = node.Role;
            if any(strcmp(role,["central","peripheral","isochronous-broadcaster","synchronized-receiver","broadcaster","observer"]))
                for idx = 1:numel(node.pAppStatistics)
                    if node.pAppStatistics(idx).ReceivedPackets>0
                        node.pAppStatistics(idx).AveragePacketLatency = ...
                            node.pAppStatistics(idx).AggregatePacketLatency/node.pAppStatistics(idx).ReceivedPackets;
                    end
                end
                nodeStatistics(nodeIdx).App = node.pAppStatistics;
            elseif strcmp(role,"broadcaster-observer")
                for idx = 1:numel(node.pMeshAppStatisticsList)
                    if node.pMeshAppStatisticsList(idx).ReceivedPackets>0
                        node.pMeshAppStatisticsList(idx).AveragePacketLatency = ...
                            node.pMeshAppStatisticsList(idx).AggregatePacketLatency/node.pMeshAppStatisticsList(idx).ReceivedPackets;
                    end
                end
                meshStats = statistics(node.pMesh);
                nodeStatistics(nodeIdx).App = node.pMeshAppStatisticsList;
                nodeStatistics(nodeIdx).Transport = meshStats.Transport;
                nodeStatistics(nodeIdx).Network = meshStats.Network;
            end

            nodeStatistics(nodeIdx).LL = statistics(node.pLinkLayer);
            phyStats = statistics(phyRx);
            phyStats.TransmittedPackets = phyTx.TransmittedPackets;
            phyStats.TransmittedBits = phyTx.TransmittedBits;
            nodeStatistics(nodeIdx).PHY = phyStats;
        end
    end

    function kpiValue = kpi(sourceNode,destinationNode,kpiString,options)
        %kpi Returns the key performance indicator (KPI), kpiValue,
        %specified by kpiString, from the sourceNode to the destinationNode.

        arguments
            sourceNode (1,:) bluetoothLENode
            destinationNode (1,:) bluetoothLENode
            kpiString (1,1) string {mustBeMember(kpiString,["throughput","latency","PLR","PDR"])}
            options.Layer (1,1) string {mustBeMember(options.Layer,["App","LL"])}
        end
        validateKPINodes(sourceNode,destinationNode);
        if ~isfield(options,"Layer")
            error(message("bluetooth:bleShared:KPIMustHaveLayerNV"));
        end
        layer = options.Layer;

        % Validate invalid input combinations
        invalidCombination = false;
        srcRole = sourceNode(1).Role;
        if (sourceNode(1).NumPeriodicAdvs==0 && strcmp(srcRole,"broadcaster"))
            invalidCombination = true;
        else
            if strcmp(layer,"App")
                if strcmp(kpiString,"throughput")
                    invalidCombination = true;
                end
            elseif strcmp(layer,"LL")
                if strcmp(srcRole,"broadcaster-observer")
                    invalidCombination = true;
                else
                    if strcmp(kpiString,"latency")
                        invalidCombination = true;
                    elseif strcmp(kpiString,"throughput")
                        if (sourceNode(1).NumPeriodicAdvs>0 && strcmp(srcRole,"broadcaster"))
                            invalidCombination = true;
                        end
                    end
                end
            end
        end
        if invalidCombination
            error(message("bluetooth:bleShared:KPIInvalidInputCombination",...
                layer,kpiString,srcRole,destinationNode(1).Role));
        end

        % Return kpiValue(s). If there are multiple links provided as input, the
        % function will return the kpiValue(s) in a vector.
        numSources = numel(sourceNode);
        numDestinations = numel(destinationNode);
        kpiValue = zeros(1,max(numSources,numDestinations));

        % Run for all sourceNode-destinationNode pairs to obtain the
        % requested KPI.
        for srcIdx = 1:numSources
            for dstIdx = 1:numDestinations
                % Return default value as the node is not yet simulated
                if isempty(sourceNode(srcIdx).pCurrentTimeInMicroseconds)
                    return;
                end

                kpiIdx = max(srcIdx,dstIdx);
                if strcmp(kpiString,"throughput")
                    kpiValue(kpiIdx) = calculateThroughput(sourceNode(srcIdx),destinationNode(dstIdx));
                elseif strcmp(kpiString,"latency")
                    kpiValue(kpiIdx) = calculateLatency(sourceNode(srcIdx),destinationNode(dstIdx));
                elseif strcmp(kpiString,"PLR") % Packet loss ratio
                    plr = calculatePLR(sourceNode(srcIdx),destinationNode(dstIdx),layer);
                    if ~isempty(plr)
                        kpiValue(kpiIdx) = plr;
                    end
                elseif strcmp(kpiString,"PDR") % Packet delivery ratio
                    plr = calculatePLR(sourceNode(srcIdx),destinationNode(dstIdx),layer);
                    if ~isempty(plr)
                        kpiValue(kpiIdx) = 1 - plr;
                    end
                end
            end
        end
    end
end

methods (Hidden)
    function addConnection(obj,connectionConfig,cisConfig)
        %addConnection Add connection to the node by configuring the
        %connection parameters. This is applicable only for central and
        %peripheral nodes.

        % Connection is only applicable for central and peripheral roles
        if ~any(strcmp(obj.Role,{'central','peripheral'}))
            return;
        end

        if strcmp(obj.Role,"peripheral")
            destinationName = connectionConfig.CentralName;
            destinationID = connectionConfig.CentralID;
        else
            destinationName = connectionConfig.PeripheralName;
            destinationID = connectionConfig.PeripheralID;
        end

        % Update the number of connections and the connection configuration
        obj.NumConnections = obj.NumConnections + 1;
        obj.ConnectionConfig(obj.NumConnections) = connectionConfig;
        obj.pConnectedNodes(obj.NumConnections) = destinationName;
        obj.ConnectedNodeIDs(obj.NumConnections) = destinationID;

        % Update the number of CIS connections and CIS configuration
        if nargin>2 && ~isempty(cisConfig)
            obj.CISCount(obj.NumConnections) = numel(cisConfig);
            for idx = 1:numel(cisConfig)
                obj.NumCISConnections = obj.NumCISConnections + 1;
                obj.CISConfig(obj.NumCISConnections) = cisConfig(idx);
            end
        else
            obj.CISCount(obj.NumConnections) = 0; % No CIS connections
        end
    end

    function addPeriodicAdvertisements(obj,advConfig)
        %addPeriodicAdvertisements Add periodic advertisements to the node by
        %configuring the synchronization information. This is applicable only for
        %broadcaster and observer nodes.

        if ~any(strcmp(obj.Role,{'broadcaster','observer'}))
            return;
        end

        % Update the number of periodic advertising configurations at node
        obj.NumPeriodicAdvs = obj.NumPeriodicAdvs + 1;
        obj.PeriodicAdvConfig(obj.NumPeriodicAdvs) = advConfig;
        if strcmp(obj.Role,"observer")
            obj.pConnectedNodes(obj.NumPeriodicAdvs) = advConfig.BroadcasterName;
            obj.ConnectedNodeIDs(obj.NumPeriodicAdvs) = advConfig.BroadcasterID;
        end
    end

    function addBIG(obj,bigConfig)
        %addBIG Add BIG parameters configuration to the node. This is
        %applicable only for isochronous broadcaster and synchronized
        %receiver nodes.

        % BIG configuration is only applicable for isochronous broadcaster
        % and synchronized receiver roles
        if ~any(strcmp(obj.Role,{'isochronous-broadcaster','synchronized-receiver'}))
            return;
        end

        % Validate the input types
        validateattributes(bigConfig,{'bluetoothLEBIGConfig'},{'scalar'},...
            obj.pFileName,"bigConfig",2);

        % Update the BIG configuration
        obj.BIGPresent = true;
        obj.BIGConfig = bigConfig;
    end

    function addMeshFriendship(obj,friendshipConfig)
        %addMeshFriendship Add mesh friendship timing parameters
        %configuration to the node. This is applicable only for
        %broadcaster-observer Role.

        % Friendship configuration is only applicable for mesh role
        % (broadcaster-observer)
        if ~strcmp(obj.Role,"broadcaster-observer")
            return;
        end

        % Validate the input type
        validateattributes(friendshipConfig,{'bluetoothMeshFriendshipConfig'},{'scalar'},...
            obj.pFileName,"FriendshipConfig",2);

        % Update the mesh friendship configuration
        obj.FriendshipConfig = friendshipConfig;
        obj.FriendshipEstablished = true;
    end

    function nextInvokeTime = run(obj,currentTime)
        %run Run the layers of the Bluetooth LE node at the current time
        %instant
        %
        %   NEXTINVOKETIME = run(OBJ,CURRENTTIME) runs the Bluetooth
        %   LE node at the current time instant, CURRENTTIME, and runs all
        %   the events scheduled at the current time. This function returns
        %   the time instant at which the node runs again.
        %
        %   NEXTINVOKETIME is a nonnegative numeric scalar specifying the
        %   time instant (in seconds) at which the Bluetooth LE node runs
        %   again.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   CURRENTTIME is a nonnegative numeric scalar specifying the
        %   current simulation time in seconds.
        
        % Initialize the node
        if ~obj.pIsInitialized
            init(obj);
        end
        % Update the simulation time
        obj.CurrentTime = currentTime;
        obj.pCurrentTimeInMicroseconds = round(currentTime*1e6,3);

        % Rx buffer has data to be processed
        if obj.ReceiveBufferIdx~=0
            % Process the data in the Rx buffer
            for idx = 1:obj.ReceiveBufferIdx
                % Get the data from the Rx buffer and process the data
                nextInvokeTimeInMicroseconds = runLayers(obj,obj.ReceiveBuffer{idx});
            end
            obj.ReceiveBufferIdx = 0;
        else % Rx buffer has no data to process
            % Advance the current time by elapsed time and run all the
            % layers
            nextInvokeTimeInMicroseconds = runLayers(obj,[]);
        end
        nextInvokeTime = round(nextInvokeTimeInMicroseconds/1e6,9);
    end

    function pushReceivedData(obj,packet)
        %pushReceivedData Push the received packet to node
        %
        %   pushReceivedData(OBJ, PACKET) pushes the received packet,
        %   PACKET, from the channel to the reception buffer of the node.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   PACKET is the packet received from the channel, specified as a
        %   structure of the format <a
        %   href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.

        % Copy the received signal to the buffer
        obj.ReceiveBufferIdx = obj.ReceiveBufferIdx + 1;
        obj.ReceiveBuffer{obj.ReceiveBufferIdx} = packet;
    end

    function [flag,rxInfo] = isPacketRelevant(obj,packet)
        %isPacketRelevant Return flag to indicate whether packet is
        %relevant for the node
        %
        %   [FLAG, RXINFO] = isPacketRelevant(OBJ, PACKET) returns a flag,
        %   FLAG, specifying whether the incoming packet, PACKET, is
        %   relevant for the node. The object function also returns the
        %   receiver information, RXINFO, required to apply channel
        %   information on the incoming packet.
        %
        %   FLAG is a logical scalar value indicating whether to invoke
        %   channel or not.
        %
        %   The object function returns the output, RXINFO, and is
        %   valid only when the FLAG value is 1 (true). The structure
        %   of this output contains these fields:
        %
        %   ID       - Node identifier of the receiver
        %   Position - Current receiver position in Cartesian coordinates,
        %              specified as a real-valued vector of the form [x y
        %              z]. Units are in meters.
        %   Velocity - Current receiver velocity (v) in the x-, y-, and
        %              z-directions, specified as a real-valued vector of
        %              the form [vx vy vz]. Units are in meters per second.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   PACKET is the incoming packet to the channel, specified as a
        %   structure of the format <a
        %   href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.

        % Initialize
        flag = false;
        rxInfo = obj.pRxInfo;

        % Ignore packet transmitted by this node
        if packet.TransmitterID==obj.ID
            return;
        end

        % Transmitter position and frequency
        txPosition = packet.TransmitterPosition;
        txStartFrequency = packet.CenterFrequency - packet.Bandwidth/2;
        txEndFrequency = packet.CenterFrequency + packet.Bandwidth/2;

        offset = obj.pMaxInterferenceOffsetVal;

        % Invoke channel if signal lies in the 2.4 GHz band. The 2.4 GHz
        % band starts at 2.4 GHz and ends at 2.4835 GHz.
        if (txStartFrequency >= obj.BluetoothLEStartBand-offset && txStartFrequency <= obj.BluetoothLEEndBand+offset) || ...
                (txEndFrequency >= obj.BluetoothLEStartBand-offset && txEndFrequency <= obj.BluetoothLEEndBand+offset)
            % Calculate the distance between the transmitter and receiver in meters
            distance = norm(txPosition - obj.Position);

            % Invoke channel if the transmitter lies within the range of
            % receiving node
            if (distance<=obj.ReceiverRange)
                flag = true;
                rxInfo.Position = obj.Position;
                rxInfo.Velocity = obj.Velocity;
            end
        end
    end
end

methods (Access=protected)
    function init(obj)
    %init Initialize the Bluetooth LE node and its internal modules

        % Initialize LL
        role = obj.Role;
        if any(strcmp(role,["central","peripheral"]))
            appStats = repmat(obj.pAppStatistics,1,obj.PeripheralCount);
            obj.pLinkLayer.PeripheralCount = obj.PeripheralCount;
            obj.pLinkLayer.TransmitterPower = obj.TransmitterPower;
            cfgIndex = 1;
            for idx = 1:obj.NumConnections
                if strcmp(role,"central")
                    appStats(idx).DestinationNode = obj.ConnectionConfig(idx).PeripheralName;
                else
                    appStats(idx).DestinationNode = obj.ConnectionConfig(idx).CentralName;
                end
                if obj.CISCount(idx)
                    cisCfg = obj.CISConfig(cfgIndex:(cfgIndex + obj.CISCount(idx) - 1));
                    updateConnectionConfig(obj.pLinkLayer,idx,obj.ConnectionConfig(idx),cisCfg);
                    cfgIndex = cfgIndex + obj.CISCount(idx);
                else
                    updateConnectionConfig(obj.pLinkLayer,idx,obj.ConnectionConfig(idx));
                end
            end
            obj.pAppStatistics = appStats;
        elseif any(strcmp(role,["broadcaster","observer"]))
            if obj.NumPeriodicAdvs>0 % Periodic advertisements
                % Use weak-references for cross-linking handle objects
                objWeakRef = matlab.lang.WeakReference(obj);
                notificationFcn = @(eventName,eventData) objWeakRef.Handle.triggerEvent(eventName,eventData);

                obj.pLinkLayer = ble.internal.linkLayerPeriodicAdv(notificationFcn,obj.Role,TransmitterPower=obj.TransmitterPower);
                appStats = repmat(obj.pAppStatistics,1,obj.NumPeriodicAdvs);
                for idx = 1:obj.NumPeriodicAdvs
                    if strcmp(role,"broadcaster")
                        appStats(idx).DestinationNode = obj.PeriodicAdvConfig(idx).ObserverName;
                    else
                        appStats(idx).DestinationNode = obj.PeriodicAdvConfig(idx).BroadcasterName;
                    end
                    updateAdvertisingConfig(obj.pLinkLayer,idx,obj.PeriodicAdvConfig(idx));
                end
                obj.pAppStatistics = appStats;
            else % Legacy advertisements
                obj.pLinkLayer.AdvertisingInterval = obj.AdvertisingInterval;
                obj.pLinkLayer.ScanInterval = obj.ScanInterval;
                obj.pLinkLayer.RandomAdvertising = obj.RandomAdvertising;
                obj.pLinkLayer.PreemptiveScanning = obj.PreemptiveScanning;
                obj.pLinkLayer.TransmitterPower = obj.TransmitterPower;
            end
        elseif any(strcmp(role,["isochronous-broadcaster","synchronized-receiver"]))
            obj.pLinkLayer.Role = role;
            obj.pLinkLayer.TransmitterPower = obj.TransmitterPower;
            updateBIGConfig(obj.pLinkLayer,obj.BIGConfig);
        elseif strcmp(role,"broadcaster-observer")
            obj.pLinkLayer.AdvertisingInterval = obj.AdvertisingInterval;
            obj.pLinkLayer.ScanInterval = obj.ScanInterval;
            obj.pLinkLayer.RandomAdvertising = obj.RandomAdvertising;
            obj.pLinkLayer.PreemptiveScanning = obj.PreemptiveScanning;
            obj.pLinkLayer.TransmitterPower = obj.TransmitterPower;
            if obj.MeshConfig.LowPower
                updateLPNState(obj.pLinkLayer,obj.pMesh.LPNSleeping);
            end
            % Initialize mesh profile
            init(obj.pMesh,obj.MeshConfig);
            % Add friendship configuration at mesh profile
            if obj.FriendshipEstablished
                configureFriendship(obj.pMesh,obj.FriendshipConfig);
            end
            obj.pMeshAppStatisticsList = obj.pMeshAppStatistics;
        end
        init(obj.pLinkLayer);

        % Initialize PHY transmitter
        obj.pPHYTransmitter.TransmitterGain = obj.TransmitterGain;

        % Initialize PHY receiver
        obj.PHYReceiver.NoiseFigure = obj.NoiseFigure;
        obj.PHYReceiver.ReceiverGain = obj.ReceiverGain;
        obj.PHYReceiver.ReceiverSensitivity = obj.ReceiverSensitivity;
        obj.PHYReceiver.InterferenceModeling = obj.InterferenceModeling;
        obj.PHYReceiver.MaxInterferenceOffset = obj.MaxInterferenceOffset;
        init(obj.PHYReceiver);

        if strcmp(obj.InterferenceModeling,obj.InterferenceModeling_Values(1))
            obj.pMaxInterferenceOffsetVal = 0;
        else
            obj.pMaxInterferenceOffsetVal = obj.MaxInterferenceOffset;
        end

        % Fill node ID in the Tx buffer        
        obj.pIsInitialized = true;

        % Checks whether events have listeners
        checkEventListeners(obj);
    end

    function nextInvokeTime = runLayers(obj,signal)
    %runLayers Runs the layers within the node with the received signal and
    %returns the next invoke time (in microseconds)

        mesh = obj.pMesh; % Mesh profile object
        nextMeshTime = Inf;
        linkLayer = obj.pLinkLayer; % Link layer object
        phyTx = obj.pPHYTransmitter; % PHY transmitter object
        phyRx = obj.PHYReceiver; % PHY receiver object

        % Invoke the application data generators, and push data to lower
        % layers
        nextAppTime = run(obj.pTrafficManager,round(obj.pCurrentTimeInMicroseconds*1e3));
        nextAppTime = round(nextAppTime/1e3,3);

        % Invoke the PHY receiver module
        [nextPHYRxTime,indicationFromPHY] = run(phyRx,obj.pCurrentTimeInMicroseconds,signal);

        % Inform the link layer that a Bluetooth LE signal containing data has been
        % received at the PHY for processing
        role = obj.Role;
        if strcmp(role,"broadcaster-observer")
            if ~isempty(phyRx.CurrentSignal) && (phyRx.CurrentSignal.Type==ble.internal.networkUtilities.BluetoothLESignal)
                updatePHYSignalInfo(linkLayer,true);
            else
                updatePHYSignalInfo(linkLayer,false);
            end
        end

        % Invoke the link layer module
        [nextLLTime,requestToPHY] = run(linkLayer,obj.pCurrentTimeInMicroseconds,indicationFromPHY);

        % LL requests PHY receiver
        if ~isempty(linkLayer.RxRequest)
            phyRx.RxRequest = linkLayer.RxRequest;
        end

        if any(strcmp(role,["central","peripheral","observer"]))
            % Link layer decoded successfully
            if ~isempty(linkLayer.RxUpperLayerData)
                % Application packet reception at legacy observer
                if strcmp(role,"observer") && obj.NumPeriodicAdvs==0
                    peerIdx = 1;
                    sourceNode = indicationFromPHY.RxSourceName;
                    % Trigger packet reception event for successful and failed receptions
                    if linkLayer.PacketReceived && linkLayer.HasListener.PacketReceptionEnded
                        linkLayer.NotificationFcn("PacketReceptionEnded",linkLayer.PacketReceptionEnded);
                    end
                else % Application packet reception at central, peripheral, and periodic observer
                    peerIdx = linkLayer.RxActiveConnectionIdx;
                    sourceNode = obj.pConnectedNodes(linkLayer.RxActiveConnectionIdx);
                end
                if obj.NumPeriodicAdvs>0 % Periodic observer
                    appTimestamp = linkLayer.RxUpperLayerTimestamp(linkLayer.RxActiveConnectionIdx);
                else
                    appTimestamp = linkLayer.RxUpperLayerTimestamp;
                end
                updateAppStatistics(obj,peerIdx,sourceNode,linkLayer.RxUpperLayerData,appTimestamp);
            end
        elseif any(strcmp(role,["isochronous-broadcaster","synchronized-receiver"]))
            % Link layer decoded successfully
            if ~isempty(linkLayer.RxUpperLayerData)
                peerIdx = 1;
                sourceNode = obj.BIGConfig.BroadcasterName;
                updateAppStatistics(obj,peerIdx,sourceNode,linkLayer.RxUpperLayerData,linkLayer.RxUpperLayerTimestamp);
            end
        elseif strcmp(role,"broadcaster-observer")
            % Link layer decoded successfully
            if ~isempty(linkLayer.RxUpperLayerData)
                rxMeshPacket.Message = linkLayer.RxUpperLayerData;
                rxMeshPacket.Timestamp = linkLayer.RxUpperLayerTimestamp;
            else
                rxMeshPacket = [];
            end

            % Invoke mesh profile
            [nextMeshTime,txMeshPacket] = run(mesh,obj.pCurrentTimeInMicroseconds,rxMeshPacket);
            if obj.MeshConfig.LowPower % Set link layer state for LPN
                nextLLTime = updateLPNState(linkLayer,mesh.LPNSleeping);
            end
            if ~isempty(txMeshPacket) % Push mesh packet into link layer
                [~,nextLLTime] = pushUpperLayerPDU(linkLayer,txMeshPacket.Message,txMeshPacket.Timestamp);
            end
            % Trigger packet reception event for successful and failed receptions
            if linkLayer.PacketReceived && linkLayer.HasListener.PacketReceptionEnded
                linkLayer.NotificationFcn("PacketReceptionEnded",linkLayer.PacketReceptionEnded);
            end
            if mesh.MeshAppDataReceived.IsTriggered % Mesh decoding successful, update mesh application statistics
                updateMeshAppStats(obj,mesh.MeshAppDataReceived.SourceAddress,...
                    mesh.MeshAppDataReceived.DestinationAddress,mesh.MeshAppDataReceived.Message);
            end
        end

        % Invoke the PHY transmitter module
        txPacket = run(phyTx,requestToPHY);

        % Update the transmitted waveform along with the metadata
        if ~isempty(txPacket)
            txPacket.TransmitterID = obj.ID;
            txPacket.TransmitterPosition = obj.Position;
            txPacket.TransmitterVelocity = obj.Velocity;
            txPacket.StartTime = obj.CurrentTime;
            txPacket.Metadata.TransmitterName = obj.Name;
        end
        obj.TransmitterBuffer = txPacket;

        % Update the next invoke time as minimum of next invoke times of
        % all the modules
        nextInvokeTime = min([nextPHYRxTime nextLLTime nextMeshTime nextAppTime]);
    end

    function upperLayerData = validateUpperLayerMetadata(obj,trafficSource,varargin)
        %validateUpperLayerMetadata Validate the name-value arguments for
        %the upper layer data

        % Validate traffic source object
        if ~isa(trafficSource,"wirelessnetwork.internal.networkTraffic") || ~isscalar(trafficSource)
            error(message("wirelessnetwork:networkTraffic:InvalidTrafficSource"));
        end
        unsupportedTrafficSources = ["networkTrafficFTP" "networkTrafficVoIP" "networkTrafficVideoConference"];
        if any(strcmp(class(trafficSource),unsupportedTrafficSources))
            error(message("bluetooth:bluetoothLENode:UnsupportedTrafficSource"));
        end

        % Validate if PacketSize property is present in data source
        propList = properties(trafficSource);
        packetSizePresent = any(strcmp(propList,"PacketSize"));
        if ~packetSizePresent
            error(message("bluetooth:bluetoothLENode:PacketSizeNotPresent"));
        end

        % Initialize upper layer data structure
        upperLayerData = struct("ConnectionIndex",0,"SourceAddress","0000",...
            "DestinationAddress","0000","TTL",0,"CISID",[]);

        % Validate the roles and the respective name-value arguments
        % Send data is not applicable for the synchronized-receiver
        role = obj.Role;
        if any(strcmp(role,["synchronized-receiver","observer"]))
            error(message("bluetooth:bluetoothLENode:TrafficSourceNotApplicable",obj.Role));
        % No name-value arguments are applicable for "isochronous-broadcaster" and
        % "broadcaster" roles
        elseif any(strcmp(role,["isochronous-broadcaster","broadcaster"]))
            narginchk(2,2);
            if strcmp(role,"broadcaster")
                % In the case of "Periodic Advertisements", as networkTrafficOnOff sends
                % random application data, we assume that the data is provided to the link
                % layer by the host to be transmitted in the AdvData field of the
                % AUX_SYNC_IND. Additionally, the AdvData is considered to be
                % manufacturer-specific data, as described in the Core Specification
                % Supplement, Part A, Section 1.4. To ensure a valid GAP encoding for the
                % data to be sent in the advertising PDU, refer Core Specification v5.3,
                % Vol 3, Part C, Section 11. Thus, considering 11 bytes for the extended
                % header and 4 bytes for the header of AdvData (manufacturer-specific data)
                % out of the 255 bytes of advertising payload, the application traffic can
                % send a maximum packet size of 240 for these periodic advertisement
                % simulations.
                if obj.NumPeriodicAdvs>0
                    if trafficSource.PacketSize>(255-(11+4))
                        error(message("bluetooth:bluetoothLENode:InvalidPacketLength",obj.Role,"1","240"));
                    end
                    if ~isempty(obj.pTrafficManager.TrafficSources)
                        error(message("bluetooth:bleShared:TrafficAlreadyAdded","Broadcaster",obj.Name,"Observer",obj.PeriodicAdvConfig.ObserverName));
                    end

                % In the case of "Legacy Advertisements", As networkTrafficOnOff sends
                % random application data, we assume that the data is provided to the link
                % layer by the host to be transmitted in the AdvData field of the
                % ADV_NONCONN_IND. Additionally, the AdvData is considered to be
                % manufacturer-specific data, as described in the Core Specification
                % Supplement, Part A, Section 1.4. To ensure a valid GAP encoding for the
                % data to be sent in the advertising PDU, refer Core Specification v5.3,
                % Vol 3, Part C, Section 11. Thus, 4 bytes for the header of AdvData
                % (manufacturer-specific data) out of the 31 bytes of advertising payload,
                % the application traffic can send a maximum packet size of 27 for these
                % legacy advertisement simulations.
                else
                    if trafficSource.PacketSize>(31-4)
                        error(message("bluetooth:bluetoothLENode:InvalidPacketLength",obj.Role,"1","27"));
                    end
                end
            else
                % Refer Bluetooth Core Specification v5.3, Volume 6, Part B, Section 4.4.6.3.
                if trafficSource.PacketSize>251
                    error(message("bluetooth:bluetoothLENode:InvalidPacketLength",obj.Role,"1","251"));
                end
            end
        % DestinationNodeID is applicable for "central" and "peripheral" roles
        elseif any(strcmp(role,["central","peripheral"]))
            narginchk(4,6);
            nvPairs = {'DestinationNode','CISConfig'};
        % "SourceAddress", "DestinationAddress" and "TTL" are applicable 
        % for "broadcaster-observer" role
        elseif strcmp(role,"broadcaster-observer")
            narginchk(6,8);
            nvPairs = {'SourceAddress','DestinationAddress','TTL'};
            upperLayerData.TTL = obj.MeshConfig.TTL;
            % Refer Bluetooth Mesh Profile v1.0.1, Section 3.5.2.1.
            if trafficSource.PacketSize>15 || trafficSource.PacketSize<5
                error(message("bluetooth:bluetoothLENode:InvalidPacketLength",obj.Role,"5","15"));
            end
        end

        % Apply name-value arguments
        cisConfig = [];
        for i = 1:2:nargin-2
            value = validatestring(varargin{i},nvPairs,obj.pFileName,"name-value-arguments");
            if strcmp(value,"DestinationNode")
                destinationNode = varargin{i+1};
                if ischar(destinationNode)
                    validateattributes(destinationNode,{'char'},...
                        {'scalartext'},obj.pFileName,"DestinationNode");
                else
                    validateattributes(destinationNode,{'string','bluetoothLENode'},...
                        {'scalar'},obj.pFileName,"DestinationNode");
                end
                connectedNodes = strjoin(obj.pConnectedNodes,", ");
                if isa(destinationNode,"bluetoothLENode")
                    connectionIndex = find(destinationNode.ID==obj.ConnectedNodeIDs);
                else
                    connectionIndex = find(strcmpi(destinationNode,obj.pConnectedNodes));
                end
                if isempty(connectionIndex)
                    error(message("bluetooth:bluetoothLENode:InvalidDestinationNode",connectedNodes(1,:)));
                end
                if numel(connectionIndex)>1
                    error(message("bluetooth.bluetoothLENode:SameDestinationName"));
                end
                upperLayerData.ConnectionIndex = connectionIndex;
            elseif strcmp(value,"CISConfig")
                validateattributes(varargin{i+1},{'bluetoothLECISConfig'},...
                    {'scalar'},obj.pFileName,"CISConfig");
                cisConfig = varargin{i+1};
                upperLayerData.CISID = cisConfig.CISID;
                if trafficSource.PacketSize>cisConfig.MaxPDU
                    error(message("bluetooth:bluetoothLENode:InvalidPacketLength",obj.Role,"1",num2str(cisConfig.MaxPDU)));
                end
            elseif strcmp(value,"SourceAddress")
                % Validate the input source address field. Refer Mesh
                % Profile v1.0.1 of Bluetooth Specification | Section
                % 3.4.4.6
                srcAddress = varargin{i+1};
                ble.internal.validateHex(srcAddress,4,"SourceAddress");
                addressBinary = int2bit(hex2dec(srcAddress),16);
                if (~(addressBinary(1)==0 && sum(addressBinary)~=0))
                    error(message("bluetooth:bluetoothLENode:AddTrafficInvalidSRC"));
                end
                upperLayerData.SourceAddress = char(srcAddress);
            elseif strcmp(value,"DestinationAddress")
                % Validate the input destination address field. Refer
                % Mesh Profile v1.0.1 of Bluetooth Specification |
                % Section 3.4.4.7
                dstAddress = varargin{i+1};
                ble.internal.validateHex(dstAddress,4,"DestinationAddress");
                upperLayerData.DestinationAddress = char(dstAddress);
            elseif strcmp(value,"TTL")
                % Validate the input time to live field. Refer Mesh
                % Profile v1.0.1 of Bluetooth Specification | Section
                % 3.6.4.4
                ttl = varargin{i+1};
                validateattributes(ttl,{'numeric'},{'scalar','integer','nonempty',...
                    'nonnegative','<=',127},obj.pFileName,"TTL");
                upperLayerData.TTL = ttl;
            end
        end

        % Validate traffic packet size is less than or equal to MaxPDU
        if any(strcmp(role,["central","peripheral"])) && isempty(cisConfig)
            connectionConfig = obj.ConnectionConfig(connectionIndex);
            maxPDU = connectionConfig.MaxPDU;
            if isscalar(maxPDU)
                [payloadLengthC2P,payloadLengthP2C] = deal(connectionConfig.MaxPDU);
            else
                payloadLengthC2P = connectionConfig.MaxPDU(1);
                payloadLengthP2C = connectionConfig.MaxPDU(2);
            end
            if strcmp(obj.Role,"central")
                if trafficSource.PacketSize>payloadLengthC2P
                    error(message("bluetooth:bluetoothLENode:InvalidPacketLength",obj.Role,"1",num2str(payloadLengthC2P)));
                end
            else
                if trafficSource.PacketSize>payloadLengthP2C
                    error(message("bluetooth:bluetoothLENode:InvalidPacketLength",obj.Role,"1",num2str(payloadLengthP2C)));
                end
            end
        end
    end

    function isPushed = pushUpperLayerData(obj,upperLayerData)
        %pushUpperLayerData Push the upper layer data into the lower layer
        %based on role

        role = obj.Role;
        if any(strcmp(role,["central","peripheral"]))
            connectionIndex = upperLayerData.ConnectionIndex;
            % Push the application data into the CIS queue, based on the connection
            % index (which denotes the peripheral index) and the CISID (which
            % represents the specific CIS connection to which the data packet is
            % directed)
            if ~isempty(upperLayerData.CISID)
                isPushed = pushUpperLayerPDU(obj.pLinkLayer,connectionIndex,...
                    upperLayerData.Packet,obj.pCurrentTimeInMicroseconds,upperLayerData.CISID);
            % Push the application data into connections (ACL) queue, based on the
            % connection index (which denotes the peripheral index)
            else
                isPushed = pushUpperLayerPDU(obj.pLinkLayer,connectionIndex,...
                    upperLayerData.Packet,obj.pCurrentTimeInMicroseconds);
            end

            obj.pAppStatistics(connectionIndex).TransmittedPackets = ...
                obj.pAppStatistics(connectionIndex).TransmittedPackets + 1;
            obj.pAppStatistics(connectionIndex).TransmittedBytes = ...
                obj.pAppStatistics(connectionIndex).TransmittedBytes + numel(upperLayerData.Packet);
        elseif strcmp(role,"broadcaster-observer")
            srcAddress = upperLayerData.SourceAddress;
            dstAddress = upperLayerData.DestinationAddress;
            ttl = upperLayerData.TTL;
            isPushed = pushAccessMessage(obj.pMesh.TransportLayer,upperLayerData.Packet,...
                srcAddress,dstAddress,ttl,obj.pCurrentTimeInMicroseconds);
            updateMeshAppStats(obj,srcAddress,dstAddress,upperLayerData.Packet);
        elseif any(strcmp(role,["isochronous-broadcaster","broadcaster"]))
            isPushed = pushUpperLayerPDU(obj.pLinkLayer,upperLayerData.Packet,obj.pCurrentTimeInMicroseconds);
            obj.pAppStatistics(1).TransmittedPackets = ...
                obj.pAppStatistics(1).TransmittedPackets + 1;
            obj.pAppStatistics(1).TransmittedBytes = ...
                obj.pAppStatistics(1).TransmittedBytes + numel(upperLayerData.Packet);
        end
    end

    function updateAppStatistics(obj,peerIdx,sourceNode,appData,appTimestamp)
        %updateAppStatistics Update application statistics for "central",
        %"peripheral", "isochronous-broadcaster", "synchronized-receiver", and
        %"receiver" roles

        obj.pAppStatistics(peerIdx).ReceivedPackets = ...
            obj.pAppStatistics(peerIdx).ReceivedPackets + 1;
        obj.pAppStatistics(peerIdx).ReceivedBytes = ...
            obj.pAppStatistics(peerIdx).ReceivedBytes + numel(appData);
        packetLatency = (obj.pCurrentTimeInMicroseconds - appTimestamp)/1e6;
        obj.pAppStatistics(peerIdx).AggregatePacketLatency = ...
            obj.pAppStatistics(peerIdx).AggregatePacketLatency + packetLatency;

        % Trigger app packet reception event
        if obj.pLinkLayer.HasListener.AppDataReceived
            eventData = obj.pAppDataReceived;
            eventData.SourceNode = sourceNode;
            eventData.ReceivedData = appData;
            triggerEvent(obj,"AppDataReceived",eventData);
        end
    end

    function updateMeshAppStats(obj,srcAddress,dstAddress,message)
        %updateMeshAppStats Update mesh application statistics

        meshAppIdx = -1;
        % Get the application index to which the packet belongs
        for idx = 1:obj.pMeshAppSize
            if (strcmpi(obj.pMeshAppStatisticsList(idx).SourceAddress,srcAddress) ...
                    && strcmpi(obj.pMeshAppStatisticsList(idx).DestinationAddress,dstAddress))
                meshAppIdx = idx;
                break;
            end
        end

        % Add a new application statistics structure to the list
        if meshAppIdx==-1
            obj.pMeshAppSize = obj.pMeshAppSize + 1;
            obj.pMeshAppStatisticsList(obj.pMeshAppSize) = obj.pMeshAppStatistics;
            meshAppIdx = obj.pMeshAppSize;
            % Update source and destination element addresses at the application
            % statistics
            obj.pMeshAppStatisticsList(meshAppIdx).SourceAddress = srcAddress;
            obj.pMeshAppStatisticsList(meshAppIdx).DestinationAddress = dstAddress;
        end
        appStats = obj.pMeshAppStatisticsList(meshAppIdx);

        % Update the application receive statistics
        if obj.pMesh.MeshAppDataReceived.IsTriggered
            obj.pMesh.MeshAppDataReceived.IsTriggered = false;
            rxMeshApptimestamp = obj.pMesh.MeshAppDataReceived.Timestamp;
            appStats.ReceivedPackets = appStats.ReceivedPackets + 1;
            appStats.ReceivedBytes = appStats.ReceivedBytes + numel(message);
            packetLatency = (obj.pCurrentTimeInMicroseconds - rxMeshApptimestamp)/1e6;
            appStats.AggregatePacketLatency = appStats.AggregatePacketLatency + packetLatency;
        else % Update the application transmit statistics
            appStats.TransmittedPackets = appStats.TransmittedPackets + 1;
            appStats.TransmittedBytes = appStats.TransmittedBytes + numel(message);
        end
        obj.pMeshAppStatisticsList(meshAppIdx) = appStats;

        % Trigger mesh app packet reception event
        if obj.pLinkLayer.HasListener.MeshAppDataReceived
            eventData = obj.pMeshAppDataReceived;
            eventData.Message = message;
            eventData.SourceAddress = srcAddress;
            eventData.DestinationAddress = dstAddress;
            triggerEvent(obj,"MeshAppDataReceived",eventData);
        end
    end

    function checkEventListeners(obj)
        %checkEventListeners Checks whether events have listeners and returns a
        %structure with event names as field names holding flags indicating true if
        %it has a listener.

        hasListenerEvtStruct = ble.internal.networkUtilities.defaultEventList;

        if event.hasListener(obj,'PacketTransmissionStarted')
            hasListenerEvtStruct.PacketTransmissionStarted = true;
        end
        if event.hasListener(obj,'PacketReceptionEnded')
            hasListenerEvtStruct.PacketReceptionEnded = true;
        end
        if event.hasListener(obj,'ChannelMapUpdated')
            hasListenerEvtStruct.ChannelMapUpdated = true;
        end
        if event.hasListener(obj,'ConnectionEventEnded')
            hasListenerEvtStruct.ConnectionEventEnded = true;
        end
        if event.hasListener(obj,'AppDataReceived')
            hasListenerEvtStruct.AppDataReceived = true;
        end
        if event.hasListener(obj,'SleepStateTransition')
            hasListenerEvtStruct.SleepStateTransition = true;
        end
        if event.hasListener(obj,'MeshAppDataReceived')
            hasListenerEvtStruct.MeshAppDataReceived = true;
        end

        obj.pLinkLayer.HasListener = hasListenerEvtStruct;
        obj.pPHYTransmitter.HasListener = hasListenerEvtStruct;
    end

    function triggerEvent(obj,eventName,eventData)
        %triggerEvent Trigger the event to notify all the listeners
        objWeakRef = matlab.lang.WeakReference(obj);
        if event.hasListener(obj,eventName)
            eventData.NodeName = obj.Name;
            eventData.NodeID = obj.ID;
            eventData.CurrentTime = obj.CurrentTime;
            eventDataObj = wirelessnetwork.internal.nodeEventData;
            eventDataObj.Data = eventData;
            notify(objWeakRef.Handle,eventName,eventDataObj);
        end
    end

    function validateKPINodes(sourceNode,destinationNode)
        % Custom validation function for KPI method

        % Validate nodes to have expected roles
        if (~isscalar(sourceNode) && ~isscalar(destinationNode))
            error(message("bluetooth:bleShared:KPIInvalidSignature"));
        end

        % Validate that all nodes specified in the sourceNode or destinationNode vectors have the same roles
        if ~isscalar(sourceNode) && numel(unique(arrayfun(@(x) char(x.Role),sourceNode,'UniformOutput',false)))>1
            error(message("bluetooth:bleShared:KPIMustHaveSameRole","source nodes"));
        elseif ~isscalar(destinationNode) && numel(unique(arrayfun(@(x) char(x.Role),destinationNode,'UniformOutput',false)))>1
            error(message("bluetooth:bleShared:KPIMustHaveSameRole","destination nodes"));
        end

        % Validate that the source and destination nodes have valid combinations of roles
        validRolePairs = ["central/peripheral","peripheral/central","isochronous-broadcaster/synchronized-receiver",...
            "broadcaster/observer","broadcaster-observer/broadcaster-observer"];
        rolePair = strcat(sourceNode(1).Role,"/",destinationNode(1).Role);
        if ~any(strcmp(rolePair,validRolePairs))
            error(message("bluetooth:bleShared:KPIInvalidRoleCombination",rolePair,strjoin(validRolePairs, ', ')));
        end
    end

    function throughput = calculateThroughput(sourceNode,destinationNode)
        %calculateThroughput Returns the throughput (in Kbps) from the
        %sourceNode to the destinationNode

        throughput = 0;
        srcStats = statistics(sourceNode);
        if any(strcmp(sourceNode.Role,["central","peripheral"])) % LE piconet - Throughput at LL
            stats = srcStats.LL(arrayfun(@(x) x.PeerNodeID==destinationNode.ID,srcStats.LL));
            if sourceNode.pCurrentTimeInMicroseconds>0 && ~isempty(stats)
                throughput = (stats.TransmittedPayloadBytes*8*1e3)/sourceNode.pCurrentTimeInMicroseconds; % LE-ACL throughput
                if ~isempty(stats.CISStatistics) % If LE-CIS is present, then aggregate both throughputs
                    cisThroughput = (sum(arrayfun(@(x) x.TransmittedPayloadBytes,stats.CISStatistics))*8*1e3)/sourceNode.pCurrentTimeInMicroseconds;
                    throughput = throughput + cisThroughput;
                end
            end
        else % LE BIG - Throughput at LL
            if sourceNode.pCurrentTimeInMicroseconds>0
                dataBytes = sum(srcStats.LL.TransmittedBytes(destinationNode.BIGConfig.ReceiveBISNumbers));
                throughput = (dataBytes*8*1e3)/sourceNode.pCurrentTimeInMicroseconds;
            end
        end
    end

    function latency = calculateLatency(sourceNode,destinationNode)
        %calculateLatency Returns the one way end-to-end latency (in seconds)
        %from the sourceNode to the destinationNode

        latency = 0;
        dstStats = statistics(destinationNode);
        % LE piconet and LE periodic advertisements - Latency at App
        if any(strcmp(sourceNode.Role,["central","peripheral","broadcaster"]))
            stats = dstStats.App(arrayfun(@(x) strcmp(x.DestinationNode,sourceNode.Name),dstStats.App));
            if ~isempty(stats)
                latency = stats.AveragePacketLatency;
            end

        % LE BIG - Latency at App
        elseif strcmp(sourceNode.Role,"isochronous-broadcaster")
            latency = dstStats.App.AveragePacketLatency;

        % Bluetooth mesh - Latency at App
        elseif strcmp(sourceNode.Role,"broadcaster-observer")
            stats = dstStats.App(arrayfun(@(x) ismember(x.SourceAddress,sourceNode.MeshConfig.ElementAddress),dstStats.App));
            if ~isempty(stats)
                latency = mean(arrayfun(@(x) x.AveragePacketLatency,stats));
            end
        end
    end

    function plr = calculatePLR(sourceNode,destinationNode,layer)
        %calculatePLR Returns the packet loss ratio (PLR) from the
        %sourceNode to the destinationNode

        srcStats = statistics(sourceNode);
        dstStats = statistics(destinationNode);
        txPkts = 0;
        rxPkts = 0;
        plr = [];

        % LE piconet
        if any(strcmp(sourceNode.Role,["central","peripheral"]))
            if strcmp(layer,"LL") % PLR at LL
                stats = srcStats.LL(arrayfun(@(x) x.PeerNodeID==destinationNode.ID,srcStats.LL));
                if ~isempty(stats)
                    retransmittedPackets = stats.RetransmittedDataPackets;
                    transmittedPackets = stats.TransmittedDataPackets + stats.RetransmittedDataPackets;
                    if ~isempty(stats.CISStatistics) % If LE-CIS is present
                        retransmittedPackets = retransmittedPackets + sum(arrayfun(@(x) x.RetransmittedPackets,stats.CISStatistics));
                        transmittedPackets = transmittedPackets + sum(arrayfun(@(x) x.TransmittedPackets,stats.CISStatistics));
                    end
                    if transmittedPackets>0
                        plr = retransmittedPackets/transmittedPackets;
                    end
                end
                return;
            else % PLR at App
                srcAppStats = srcStats.App(arrayfun(@(x) strcmp(x.DestinationNode,destinationNode.Name),srcStats.App));
                dstAppStats = dstStats.App(arrayfun(@(x) strcmp(x.DestinationNode,sourceNode.Name),dstStats.App));
                if ~isempty(srcAppStats) && ~isempty(dstAppStats)
                    txPkts = srcAppStats.TransmittedPackets;
                    rxPkts = dstAppStats.ReceivedPackets;
                end
            end

        % LE BIG
        elseif strcmp(sourceNode.Role,"isochronous-broadcaster")
            if strcmp(layer,"LL") % PLR at LL
                bisNumbers = destinationNode.BIGConfig.ReceiveBISNumbers;
                rxPkts = sum(dstStats.LL.ReceivedDataPackets) + dstStats.LL.ReceivedDuplicatePackets;
                txPkts = sum(srcStats.LL.TransmittedDataPackets(bisNumbers)) + sum(srcStats.LL.RetransmittedDataPackets(bisNumbers));
            else % PLR at App
                txPkts = srcStats.App.TransmittedPackets;
                rxPkts = dstStats.App.ReceivedPackets;
            end

        % Bluetooth mesh - PLR at App
        elseif strcmp(sourceNode.Role,"broadcaster-observer")
            dstAppStats = dstStats.App(arrayfun(@(x) ismember(x.SourceAddress,sourceNode.MeshConfig.ElementAddress),dstStats.App));
            srcAppStats = srcStats.App(arrayfun(@(x) ismember(x.DestinationAddress,destinationNode.MeshConfig.ElementAddress),srcStats.App));
            if ~isempty(srcAppStats) && ~isempty(dstAppStats)
                txPkts = sum(arrayfun(@(x) x.TransmittedPackets,srcAppStats));
                rxPkts = sum(arrayfun(@(x) x.ReceivedPackets,dstAppStats));
            end

        % LE periodic advertisements
        elseif strcmp(sourceNode.Role,"broadcaster")
            if strcmp(layer,"LL") % PLR at LL
                dstLLStats = dstStats.LL(arrayfun(@(x) x.PeerNodeID==sourceNode.ID,dstStats.LL));
                if ~isempty(dstLLStats)
                    txPkts = srcStats.LL.TransmittedPackets;
                    rxPkts = dstLLStats.ReceivedPackets;
                end
            else % PLR at App
                dstAppStats = dstStats.App(arrayfun(@(x) strcmp(x.DestinationNode,sourceNode.Name),dstStats.App));
                if ~isempty(dstAppStats)
                    txPkts = srcStats.App.TransmittedPackets;
                    rxPkts = dstAppStats.ReceivedPackets;
                end
            end
        end
        if txPkts>0
            plr = (txPkts - rxPkts)/txPkts;
        end
    end
end
end
