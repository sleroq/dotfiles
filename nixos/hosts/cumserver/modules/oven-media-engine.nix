{ inputs, config, lib, pkgs, ... }:
let
  cfg = config.cumserver.oven-media-engine;
  
  configFile = pkgs.writeText "ovenmediaengine-config.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <Server version="8">
        <Name>OvenMediaEngine</Name>
        <Type>origin</Type>
        <IP>*</IP>
        <PrivacyProtection>${lib.boolToString cfg.privacyProtection}</PrivacyProtection>
        <StunServer>${cfg.stunServer}</StunServer>

        <Modules>
            <HTTP2>
                <Enable>true</Enable>
            </HTTP2>
        </Modules>

        <Bind>
            <Providers>
                <OVT>
                    <WorkerCount>1</WorkerCount>
                </OVT>
                <WebRTC>
                    <Signalling>
                        <Port>${toString cfg.port}</Port>
                        <WorkerCount>1</WorkerCount>
                    </Signalling>
                    <IceCandidates>
                        <IceCandidate>*:${toString cfg.webrtcPortRangeStart}-${toString cfg.webrtcPortRangeEnd}/udp</IceCandidate>
                        <TcpRelay>*:${toString cfg.turnPort}</TcpRelay>
                        <TcpForce>true</TcpForce>
                        <TcpRelayWorkerCount>1</TcpRelayWorkerCount>
                    </IceCandidates>
                </WebRTC>
                <SRT>
                    <Port>${toString cfg.srtPort}</Port>
                    <WorkerCount>1</WorkerCount>
                </SRT>
            </Providers>

            <Publishers>
                <OVT>
                    <Port>${toString cfg.tcpPort}</Port>
                    <WorkerCount>1</WorkerCount>
                </OVT>
                <WebRTC>
                    <Signalling>
                        <Port>${toString cfg.port}</Port>
                        <WorkerCount>1</WorkerCount>
                    </Signalling>
                    <IceCandidates>
                        <IceCandidate>*:${toString cfg.webrtcPortRangeStart}-${toString cfg.webrtcPortRangeEnd}/udp</IceCandidate>
                        <TcpRelay>*:${toString cfg.turnPort}</TcpRelay>
                        <TcpForce>true</TcpForce>
                        <TcpRelayWorkerCount>1</TcpRelayWorkerCount>
                    </IceCandidates>
                </WebRTC>
            </Publishers>
        </Bind>

        <VirtualHosts>
            <VirtualHost>
                <Name>default</Name>
                <Host>
                    <Names>
                        <Name>*</Name>
                    </Names>
                </Host>

                <Applications>
                    <Application>
                        <Name>app</Name>
                        <Type>live</Type>
                        <OutputProfiles>
                            <HardwareAcceleration>${lib.boolToString cfg.hardwareAcceleration}</HardwareAcceleration>
                            <OutputProfile>
                                <Name>bypass_stream</Name>
                                <OutputStreamName>''${OriginStreamName}</OutputStreamName>
                                <Encodes>
                                    ${lib.optionalString cfg.videoBypass ''
                                    <Video>
                                        <Bypass>true</Bypass>
                                    </Video>
                                    ''}
                                    ${lib.optionalString (!cfg.videoBypass) ''
                                    <Video>
                                        <Name>video_transcode</Name>
                                        <Codec>${cfg.videoCodec}</Codec>
                                        <Bitrate>${toString cfg.videoBitrate}</Bitrate>
                                        ${lib.optionalString (cfg.videoWidth != null) "<Width>${toString cfg.videoWidth}</Width>"}
                                        ${lib.optionalString (cfg.videoHeight != null) "<Height>${toString cfg.videoHeight}</Height>"}
                                        ${lib.optionalString (cfg.videoFramerate != null) "<Framerate>${toString cfg.videoFramerate}</Framerate>"}
                                        <Preset>${cfg.videoPreset}</Preset>
                                        ${lib.optionalString (cfg.videoKeyFrameInterval != null) "<KeyFrameInterval>${toString cfg.videoKeyFrameInterval}</KeyFrameInterval>"}
                                    </Video>
                                    ''}
                                    ${lib.optionalString cfg.audioBypass ''
                                    <Audio>
                                        <Bypass>true</Bypass>
                                    </Audio>
                                    ''}
                                    ${lib.optionalString (!cfg.audioBypass) ''
                                    <Audio>
                                        <Name>audio_transcode</Name>
                                        <Codec>${cfg.audioCodec}</Codec>
                                        <Bitrate>${toString cfg.audioBitrate}</Bitrate>
                                        <Samplerate>48000</Samplerate>
                                        <Channel>2</Channel>
                                    </Audio>
                                    ''}
                                </Encodes>
                            </OutputProfile>
                        </OutputProfiles>
                        <Providers>
                            <OVT />
                            <WebRTC>
                                <Timeout>${toString cfg.webrtcTimeout}</Timeout>
                            </WebRTC>
                            <SRT />
                        </Providers>
                        <Publishers>
                            <AppWorkerCount>1</AppWorkerCount>
                            <StreamWorkerCount>8</StreamWorkerCount>
                            <OVT />
                            <WebRTC>
                                <Timeout>${toString cfg.webrtcTimeout}</Timeout>
                                <Rtx>${lib.boolToString cfg.webrtcRtx}</Rtx>
                                <Ulpfec>${lib.boolToString cfg.webrtcUlpfec}</Ulpfec>
                                <JitterBuffer>${lib.boolToString cfg.webrtcJitterBuffer}</JitterBuffer>
                            </WebRTC>
                        </Publishers>
                    </Application>
                </Applications>
            </VirtualHost>
        </VirtualHosts>
    </Server>
  '';
in
{
  options.cumserver.oven-media-engine = {
    enable = lib.mkEnableOption "OvenMediaEngine streaming server";
    
    image = lib.mkOption {
      type = lib.types.str;
      default = "airensoft/ovenmediaengine:latest";
      description = "Docker image to use for OvenMediaEngine";
    };
    
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain name for OvenMediaEngine";
      example = "stream.example.com";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 3333;
      description = "WebRTC signaling port (HTTP)";
    };
    
    srtPort = lib.mkOption {
      type = lib.types.port;
      default = 9999;
      description = "SRT input port (UDP)";
    };
    
    turnPort = lib.mkOption {
      type = lib.types.port;
      default = 3478;
      description = "TURN server port";
    };
    
    tcpPort = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Additional TCP port";
    };
    
    webrtcPortRangeStart = lib.mkOption {
      type = lib.types.port;
      default = 10000;
      description = "WebRTC media port range start";
    };
    
    webrtcPortRangeEnd = lib.mkOption {
      type = lib.types.port;
      default = 10009;
      description = "WebRTC media port range end";
    };
    
    stunServer = lib.mkOption {
      type = lib.types.str;
      default = "stun.l.google.com:19302";
      description = "STUN server for WebRTC";
    };
    
    privacyProtection = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable privacy protection (GDPR compliance)";
    };
    
    hardwareAcceleration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable hardware acceleration (GPU)";
    };
    
    webrtcTimeout = lib.mkOption {
      type = lib.types.int;
      default = 30000;
      description = "WebRTC timeout in milliseconds";
    };
    
    webrtcRtx = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable WebRTC RTX (retransmission)";
    };
    
    webrtcUlpfec = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable WebRTC ULPFEC (forward error correction)";
    };
    
    webrtcJitterBuffer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable WebRTC jitter buffer";
    };

    # Video transcoding options
    videoBypass = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Bypass video encoding (passthrough). When true, video is not re-encoded.";
    };

    videoCodec = lib.mkOption {
      type = lib.types.enum [ "h264" "h265" "vp8" ];
      default = "h264";
      description = "Video codec for transcoding";
    };

    videoBitrate = lib.mkOption {
      type = lib.types.int;
      default = 2000000;
      description = "Video bitrate in bps for transcoding";
    };

    videoWidth = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Video width for transcoding. If null, keeps original width.";
    };

    videoHeight = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Video height for transcoding. If null, keeps original height.";
    };

    videoFramerate = lib.mkOption {
      type = lib.types.nullOr lib.types.float;
      default = null;
      description = "Video framerate for transcoding. If null, keeps original framerate.";
    };

    videoPreset = lib.mkOption {
      type = lib.types.enum [ "slower" "slow" "medium" "fast" "faster" ];
      default = "medium";
      description = "Video encoding preset. Slower = better quality, more CPU. Faster = lower quality, less CPU.";
    };

    videoKeyFrameInterval = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 30;
      description = "Video keyframe interval in frames. If null, uses codec default.";
    };

    # Audio transcoding options
    audioBypass = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Bypass audio encoding (passthrough). When false, audio is re-encoded to ensure WebRTC compatibility.";
    };

    audioCodec = lib.mkOption {
      type = lib.types.enum [ "aac" "opus" ];
      default = "opus";
      description = "Audio codec for transcoding. Opus is required for WebRTC compatibility.";
    };
    
    audioBitrate = lib.mkOption {
      type = lib.types.int;
      default = 128000;
      description = "Audio bitrate in bps";
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ovenmediaengine";
      description = "Data directory for OvenMediaEngine";
    };
    
    customConfigFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to custom OvenMediaEngine configuration file. If null, uses generated default config.";
    };
    
    optimizeNetworkBuffers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Optimize network buffer sizes for streaming performance";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend != null;
        message = "OCI containers backend must be configured for OvenMediaEngine to work";
      }
      {
        assertion = config.services.caddy.enable;
        message = "oven-media-engine requires Caddy to be enabled for reverse proxy. Set services.caddy.enable = true";
      }
      {
        assertion = cfg.audioBypass || cfg.audioCodec == "opus";
        message = "When audio bypass is disabled, codec should be 'opus' for WebRTC compatibility";
      }
    ];

    networking.firewall = {
      allowedTCPPorts = [
        cfg.port
        cfg.turnPort
        cfg.tcpPort
      ];
      allowedUDPPorts = [
        cfg.srtPort
      ];
      allowedUDPPortRanges = [
        { from = cfg.webrtcPortRangeStart; to = cfg.webrtcPortRangeEnd; }
      ];
    };

    boot.kernel.sysctl = lib.mkIf cfg.optimizeNetworkBuffers {
      "net.core.rmem_max" = 134217728;
      "net.core.rmem_default" = 134217728;
      "net.core.wmem_max" = 134217728;
      "net.core.wmem_default" = 134217728;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    virtualisation.oci-containers.containers = {
      ovenmediaengine = {
        inherit (cfg) image;
        autoStart = true;
        pull = "newer";
        
        ports = [
          "127.0.0.1:${toString cfg.port}:3333"
          "0.0.0.0:${toString cfg.srtPort}:9999/udp"
          "0.0.0.0:${toString cfg.turnPort}:3478"
          "0.0.0.0:${toString cfg.tcpPort}:9000"
        ] ++ map (port: "0.0.0.0:${toString port}:${toString port}/udp") 
          (lib.range cfg.webrtcPortRangeStart cfg.webrtcPortRangeEnd);
        
        volumes = [
          "${if cfg.customConfigFile != null then cfg.customConfigFile else configFile}:/opt/ovenmediaengine/bin/origin_conf/Server.xml:ro"
          "${cfg.dataDir}:/var/lib/ovenmediaengine"
        ];
        
        extraOptions = [
          "--hostname=ovenmediaengine"
          "--ulimit=nofile=65536:65536"
        ];
      };
    };

    services.caddy.virtualHosts = {
      ${cfg.domain} = {
        extraConfig = ''
          # All streaming endpoints go to OvenMediaEngine
          handle /app/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
          
          # Everything else serves the static website
          handle {
            root * ${inputs.web-cum-army.packages."${pkgs.system}".default}
            file_server
            encode zstd gzip
          }
          
          header {
            X-Content-Type-Options nosniff
            X-Frame-Options DENY
            X-XSS-Protection "1; mode=block"
            Referrer-Policy strict-origin-when-cross-origin
          }
        '';
      };
    };
  };
} 