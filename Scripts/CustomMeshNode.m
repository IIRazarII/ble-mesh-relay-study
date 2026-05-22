classdef CustomMeshNode < bluetoothLENode
% This class inherits all properties and methods of the standard MATLAB
% bluetoothLENode, but automatically overrides the internal Link Layer 
% (pLinkLayer) with the custom ConfigurableGAPBearer to support Stateful 
% Preemption and dynamic T_ChPDU intervals.
%
% Additional Name-Value pairs supported during initialization:
%   RelayStrategy   - 0 (Without), 1 (Stateless), 2 (Stateful). Default: 0
%   RandomAdvMinGap - Minimum gap for T_ChPDU in ms. Default: 1
%   RandomAdvMaxGap - Maximum gap for T_ChPDU in ms. Default: 10
%
% Note: This script has only been verified to work with MATLAB R2025b.

    properties
        % We map the custom properties directly to the node so they can be
        % passed as Name-Value pairs during the node creation.
        RelayStrategy (1,1) double {mustBeMember(RelayStrategy, [0, 1, 2])} = 0
        RandomAdvMinGap (1,1) double {mustBeNonnegative} = 1
        RandomAdvMaxGap (1,1) double {mustBeNonnegative} = 10
    end

    methods
        function obj = CustomMeshNode(varargin)
            % 1. Call the superclass constructor. 
            % The superclass dynamically parses Name-Value pairs. Since we
            % defined RelayStrategy and gaps as properties in this subclass, 
            % the superclass will automatically assign them correctly without 
            % throwing errors.
            obj@bluetoothLENode(varargin{:});
            
            % 2. Override the internal Link Layer for each created node
            for i = 1:numel(obj)
                currentNode = obj(i);
                
                % We only apply the override if the role involves GAP/Mesh
                if any(strcmp(currentNode.Role, ["broadcaster-observer", "broadcaster", "observer"]))
                    
                    % Recreate the notification callback exactly as the superclass 
                    % does, which is required to link the bearer to the node's events.
                    objWeakRef = matlab.lang.WeakReference(currentNode);
                    notificationFcn = @(eventName, eventData) objWeakRef.Handle.triggerEvent(eventName, eventData);
                    
                    % Instantiate our custom ConfigurableGAPBearer
                    customBearer = ConfigurableGAPBearer(notificationFcn, 'Role', currentNode.Role);
                    
                    % Transfer the custom configuration from the node to the bearer
                    customBearer.RelayStrategy = currentNode.RelayStrategy;
                    customBearer.RandomAdvMinGap = currentNode.RandomAdvMinGap;
                    customBearer.RandomAdvMaxGap = currentNode.RandomAdvMaxGap;
                    
                    % Overwrite the protected property of the superclass
                    currentNode.pLinkLayer = customBearer;
                end
            end
        end
    end
end