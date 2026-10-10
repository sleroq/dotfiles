mod audio;
mod desktop;
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::{
    io::{BufRead, BufReader, Write},
    os::unix::net::{UnixListener, UnixStream},
    sync::mpsc,
    time::{Duration, Instant},
};

#[derive(Parser)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}
#[derive(Subcommand, Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "kebab-case")]
pub enum Command {
    Daemon,
    Watch,
    Workspace {
        #[arg(value_parser=clap::value_parser!(u8).range(1..=10))]
        id: u8,
    },
    Audio {
        #[command(subcommand)]
        command: AudioCommand,
    },
    Drawer {
        #[arg(value_enum)]
        drawer: Drawer,
        #[arg(value_enum)]
        action: Action,
        #[arg(long, value_enum, default_value = "content")]
        #[serde(default)]
        source: HoverSource,
    },
}
fn percent(s: &str) -> Result<f64, String> {
    let n: f64 = s.parse().map_err(|_| "expected numeric percent")?;
    if n.is_finite() {
        Ok(n.clamp(0., 150.))
    } else {
        Err("percent must be finite".into())
    }
}
#[derive(Subcommand, Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "kebab-case")]
pub enum AudioCommand {
    OutputVolume {
        #[arg(value_parser=percent)]
        percent: f64,
    },
    InputVolume {
        #[arg(value_parser=percent)]
        percent: f64,
    },
    OutputMute,
    InputMute,
    StreamVolume {
        id: u32,
        #[arg(value_parser=percent)]
        percent: f64,
    },
    StreamMute {
        id: u32,
    },
    OutputDefault {
        name: String,
    },
    InputDefault {
        name: String,
    },
    StreamOutput {
        stream_id: u32,
        sink_id: u32,
    },
}
#[derive(clap::ValueEnum, Serialize, Deserialize, Debug, Clone, Copy)]
pub enum Drawer {
    Top,
    Audio,
}
#[derive(clap::ValueEnum, Serialize, Deserialize, Debug, Clone, Copy)]
pub enum Action {
    Enter,
    Leave,
    Toggle,
}
#[derive(Default, clap::ValueEnum, Serialize, Deserialize, Debug, Clone, Copy)]
pub enum HoverSource {
    Sensor,
    #[default]
    Content,
}
#[derive(Default, Serialize, Clone, PartialEq)]
pub struct Drawers {
    top: bool,
    audio: bool,
}
#[derive(Default, Serialize, Clone, PartialEq)]
pub struct State {
    desktop: desktop::Desktop,
    audio: audio::Audio,
    drawers: Drawers,
}
pub enum Event {
    Desktop(desktop::Desktop),
    Audio(audio::Audio),
    Error(String),
    Client(UnixStream, Command),
    Shutdown,
}
fn socket() -> Result<std::path::PathBuf, String> {
    if let Some(p) = std::env::var_os("DWL_HELPER_SOCKET") {
        return Ok(p.into());
    }
    Ok(std::path::PathBuf::from(
        std::env::var_os("XDG_RUNTIME_DIR").ok_or("XDG_RUNTIME_DIR is missing")?,
    )
    .join("dwl-helper.sock"))
}
fn send(stream: &mut UnixStream, value: &impl Serialize) -> std::io::Result<()> {
    serde_json::to_writer(&mut *stream, value)?;
    stream.write_all(b"\n")
}
fn bind_socket(path: &std::path::Path) -> std::io::Result<UnixListener> {
    use std::os::unix::fs::FileTypeExt;
    match UnixListener::bind(path) {
        Ok(listener) => Ok(listener),
        Err(e) if e.kind() == std::io::ErrorKind::AddrInUse => {
            if !std::fs::symlink_metadata(path)?.file_type().is_socket() {
                return Err(e);
            }
            match UnixStream::connect(path) {
                Err(probe) if probe.kind() == std::io::ErrorKind::ConnectionRefused => {
                    std::fs::remove_file(path)?;
                    UnixListener::bind(path)
                }
                _ => Err(e),
            }
        }
        Err(e) => Err(e),
    }
}
fn daemon() -> Result<(), Box<dyn std::error::Error>> {
    let path = socket()?;
    let listener = bind_socket(&path)?;
    struct Cleanup(std::path::PathBuf);
    impl Drop for Cleanup {
        fn drop(&mut self) {
            let _ = std::fs::remove_file(&self.0);
        }
    }
    let _cleanup = Cleanup(path);
    let (tx, rx) = mpsc::channel();
    let mut signals = signal_hook::iterator::Signals::new([
        signal_hook::consts::SIGTERM,
        signal_hook::consts::SIGINT,
    ])?;
    let signal_tx = tx.clone();
    std::thread::spawn(move || {
        if signals.forever().next().is_some() {
            let _ = signal_tx.send(Event::Shutdown);
        }
    });
    let desktop = desktop::start(tx.clone());
    let audio = audio::start(tx.clone());
    std::thread::spawn(move || {
        for connection in listener.incoming() {
            match connection {
                Ok(stream) => {
                    if let Err(e) = stream.set_write_timeout(Some(Duration::from_millis(100))) {
                        let _ = tx.send(Event::Error(e.to_string()));
                        continue;
                    }
                    let tx = tx.clone();
                    std::thread::spawn(move || {
                        let mut line = String::new();
                        match BufReader::new(&stream).read_line(&mut line).and_then(|_| {
                            serde_json::from_str::<Command>(&line).map_err(std::io::Error::other)
                        }) {
                            Ok(command) => {
                                let _ = tx.send(Event::Client(stream, command));
                            }
                            Err(e) => {
                                let mut stream = stream;
                                let _ =
                                    send(&mut stream, &serde_json::json!({"error":e.to_string()}));
                            }
                        }
                    });
                }
                Err(e) => {
                    let _ = tx.send(Event::Error(e.to_string()));
                }
            }
        }
    });
    let mut state = State::default();
    if let Some(path) = std::env::var_os("NOTIFY_SOCKET") {
        let notify = std::os::unix::net::UnixDatagram::unbound()?;
        notify.send_to(b"READY=1", path)?;
    }
    let mut subscribers = Vec::<UnixStream>::new();
    let mut deadlines = [None, None];
    let mut active_sources = [[false; 2]; 2];
    loop {
        let wait = deadlines
            .iter()
            .flatten()
            .min()
            .map(|t: &Instant| t.saturating_duration_since(Instant::now()))
            .unwrap_or(Duration::from_secs(86400));
        let before = state.clone();
        match rx.recv_timeout(wait) {
            Ok(Event::Shutdown) => return Ok(()),
            Ok(Event::Desktop(d)) => state.desktop = d,
            Ok(Event::Audio(a)) => state.audio = a,
            Ok(Event::Error(e)) => eprintln!("dwl-helper: {e}"),
            Ok(Event::Client(mut stream, command)) => {
                let result = match command {
                    Command::Watch => {
                        if send(&mut stream, &state).is_ok() {
                            subscribers.push(stream);
                        }
                        continue;
                    }
                    Command::Workspace { id } => {
                        if !(1..=10).contains(&id) {
                            Err("workspace must be 1..10".into())
                        } else {
                            desktop.send(id).map_err(|e| e.to_string())
                        }
                    }
                    Command::Audio { command } => audio.send(command).map_err(|e| e.to_string()),
                    Command::Drawer {
                        drawer,
                        action,
                        source,
                    } => {
                        let i = match drawer {
                            Drawer::Top => 0,
                            Drawer::Audio => 1,
                        };
                        let open = match drawer {
                            Drawer::Top => state.drawers.top,
                            Drawer::Audio => state.drawers.audio,
                        };
                        let source_index = match source {
                            HoverSource::Sensor => 0,
                            HoverSource::Content => 1,
                        };
                        match action {
                            Action::Leave => {
                                active_sources[i][source_index] = false;
                                if !active_sources[i].iter().any(|active| *active) {
                                    deadlines[i] =
                                        Some(Instant::now() + Duration::from_millis(180));
                                }
                            }
                            Action::Enter | Action::Toggle => {
                                if matches!(action, Action::Enter) {
                                    active_sources[i][source_index] = true;
                                } else {
                                    active_sources[i] = [false; 2];
                                }
                                deadlines[i] = None;
                                let target = matches!(action, Action::Enter) || !open;
                                if let Err(e) = set_drawer(&mut state.drawers, drawer, target) {
                                    let _ = send(&mut stream, &serde_json::json!({"error":e}));
                                    continue;
                                }
                            }
                        }
                        Ok(())
                    }
                    _ => Err("command requires client invocation".into()),
                };
                let reply = match result {
                    Ok(()) => serde_json::json!({"ok":true}),
                    Err(e) => serde_json::json!({"error":e}),
                };
                let _ = send(&mut stream, &reply);
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {}
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                return Err("event workers disconnected".into())
            }
        }
        for (i, drawer) in [Drawer::Top, Drawer::Audio].into_iter().enumerate() {
            if deadlines[i].is_some_and(|t| t <= Instant::now()) {
                deadlines[i] = None;
                if let Err(e) = set_drawer(&mut state.drawers, drawer, false) {
                    eprintln!("dwl-helper: {e}");
                }
            }
        }
        if state != before {
            subscribers.retain_mut(|s| send(s, &state).is_ok());
        }
    }
}
fn set_drawer(state: &mut Drawers, drawer: Drawer, target: bool) -> Result<(), String> {
    let (value, name) = match drawer {
        Drawer::Top => (&mut state.top, "top-drawer"),
        Drawer::Audio => (&mut state.audio, "audio-drawer"),
    };
    if *value == target {
        return Ok(());
    }
    let config = std::env::var("DWL_EWW_CONFIG")
        .or_else(|_| std::env::var("HOME").map(|h| format!("{h}/.config/eww-dwl")))
        .map_err(|e| e.to_string())?;
    let status = std::process::Command::new("eww")
        .args([
            "--config",
            &config,
            if target { "open" } else { "close" },
            name,
        ])
        .status()
        .map_err(|e| e.to_string())?;
    if !status.success() {
        return Err(format!("eww {name}: {status}"));
    }
    *value = target;
    Ok(())
}
fn run() -> Result<(), Box<dyn std::error::Error>> {
    let command = Cli::parse().command;
    if matches!(command, Command::Daemon) {
        return daemon();
    }
    let mut stream = UnixStream::connect(socket()?)?;
    send(&mut stream, &command)?;
    let watch = matches!(command, Command::Watch);
    for line in BufReader::new(stream).lines() {
        let line = line?;
        if watch {
            println!("{line}");
        } else {
            let reply: serde_json::Value = serde_json::from_str(&line)?;
            if let Some(e) = reply.get("error") {
                return Err(e.to_string().into());
            }
            break;
        }
    }
    Ok(())
}
fn main() {
    if let Err(e) = run() {
        eprintln!("dwl-helper: {e}");
        std::process::exit(1);
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn volume_boundaries() {
        assert_eq!(percent("200").unwrap(), 150.);
        assert_eq!(percent("-3").unwrap(), 0.);
        assert!(percent("NaN").is_err());
    }
    #[test]
    fn workspace_boundaries() {
        assert!(Cli::try_parse_from(["dwl-helper", "workspace", "0"]).is_err());
        assert!(Cli::try_parse_from(["dwl-helper", "workspace", "10"]).is_ok());
    }
}
