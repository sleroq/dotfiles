use crate::Event;
use serde::Serialize;
use std::{collections::BTreeMap, sync::mpsc};
use wayland_client::{
    protocol::{wl_output, wl_registry},
    Connection, Dispatch, Proxy, QueueHandle,
};
mod protocol {
    use self::__interfaces::*;
    use wayland_client::{self, protocol::*};
    pub mod __interfaces {
        use wayland_client::backend as wayland_backend;
        use wayland_client::protocol::__interfaces::*;
        wayland_scanner::generate_interfaces!("protocols/dwl-ipc-unstable-v2.xml");
    }
    wayland_scanner::generate_client_code!("protocols/dwl-ipc-unstable-v2.xml");
}
use protocol::{zdwl_ipc_manager_v2 as manager, zdwl_ipc_output_v2 as ipc};
#[derive(Serialize, Clone, PartialEq)]
pub struct Workspace {
    id: u8,
    active: bool,
    occupied: bool,
    urgent: bool,
}
#[derive(Serialize, Clone, PartialEq)]
pub struct Desktop {
    pub monitor: String,
    title: String,
    app_id: String,
    fullscreen: bool,
    floating: bool,
    workspaces: Vec<Workspace>,
}
impl Default for Desktop {
    fn default() -> Self {
        Self {
            monitor: String::new(),
            title: String::new(),
            app_id: String::new(),
            fullscreen: false,
            floating: false,
            workspaces: (1..=10)
                .map(|id| Workspace {
                    id,
                    active: false,
                    occupied: false,
                    urgent: false,
                })
                .collect(),
        }
    }
}
struct Output {
    wl: wl_output::WlOutput,
    ipc: Option<ipc::ZdwlIpcOutputV2>,
    state: Desktop,
    active: bool,
}
struct Backend {
    manager: Option<manager::ZdwlIpcManagerV2>,
    outputs: BTreeMap<u32, Output>,
    tx: mpsc::Sender<Event>,
}
impl Dispatch<wl_registry::WlRegistry, ()> for Backend {
    fn event(
        s: &mut Self,
        r: &wl_registry::WlRegistry,
        e: wl_registry::Event,
        _: &(),
        _: &Connection,
        q: &QueueHandle<Self>,
    ) {
        match e {
            wl_registry::Event::Global {
                name,
                interface,
                version,
            } => {
                if interface == "zdwl_ipc_manager_v2" {
                    s.manager = Some(_registry_bind::<manager::ZdwlIpcManagerV2>(
                        r,
                        name,
                        version.min(2),
                        q,
                    ));
                } else if interface == "wl_output" {
                    let wl = _registry_bind::<wl_output::WlOutput>(r, name, version.min(4), q);
                    s.outputs.insert(
                        name,
                        Output {
                            wl,
                            ipc: None,
                            state: Desktop::default(),
                            active: false,
                        },
                    );
                }
                for (id, o) in &mut s.outputs {
                    if o.ipc.is_none() {
                        if let Some(m) = &s.manager {
                            o.ipc = Some(m.get_output(&o.wl, q, *id));
                        }
                    }
                }
            }
            wl_registry::Event::GlobalRemove { name } => {
                s.outputs.remove(&name);
            }
            _ => {}
        }
    }
}
fn _registry_bind<P: Proxy + 'static>(
    r: &wl_registry::WlRegistry,
    name: u32,
    version: u32,
    q: &QueueHandle<Backend>,
) -> P
where
    Backend: Dispatch<P, ()>,
{
    r.bind(name, version, q, ())
}
impl Dispatch<manager::ZdwlIpcManagerV2, ()> for Backend {
    fn event(
        _: &mut Self,
        _: &manager::ZdwlIpcManagerV2,
        _: manager::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}
impl Dispatch<wl_output::WlOutput, ()> for Backend {
    fn event(
        s: &mut Self,
        p: &wl_output::WlOutput,
        e: wl_output::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let wl_output::Event::Name { name } = e {
            if let Some(o) = s.outputs.values_mut().find(|o| o.wl == *p) {
                o.state.monitor = name;
            }
        }
    }
}
impl Dispatch<ipc::ZdwlIpcOutputV2, u32> for Backend {
    fn event(
        s: &mut Self,
        _: &ipc::ZdwlIpcOutputV2,
        e: ipc::Event,
        id: &u32,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(o) = s.outputs.get_mut(id) else {
            return;
        };
        match e {
            ipc::Event::Active { active } => o.active = active != 0,
            ipc::Event::Title { title } => o.state.title = title,
            ipc::Event::Appid { appid } => o.state.app_id = appid,
            ipc::Event::Fullscreen { is_fullscreen } => o.state.fullscreen = is_fullscreen != 0,
            ipc::Event::Floating { is_floating } => o.state.floating = is_floating != 0,
            ipc::Event::Tag {
                tag,
                state,
                clients,
                ..
            } => {
                if let Some(w) = o.state.workspaces.get_mut(tag as usize) {
                    let bits = u32::from(state);
                    w.active = bits & 1 != 0;
                    w.urgent = bits & 2 != 0;
                    w.occupied = clients != 0;
                }
            }
            ipc::Event::Frame if o.active => {
                let _ = s.tx.send(Event::Desktop(o.state.clone()));
            }
            _ => {}
        }
    }
}
pub fn start(tx: mpsc::Sender<Event>) -> mpsc::Sender<u8> {
    let (sender, rx) = mpsc::channel();
    std::thread::spawn(move || {
        if let Err(e) = run(tx.clone(), rx) {
            let _ = tx.send(Event::Error(format!("DWL IPC: {e}")));
        }
    });
    sender
}
fn run(tx: mpsc::Sender<Event>, rx: mpsc::Receiver<u8>) -> Result<(), Box<dyn std::error::Error>> {
    let conn = Connection::connect_to_env()?;
    let mut queue = conn.new_event_queue();
    let q = queue.handle();
    conn.display().get_registry(&q, ());
    let mut state = Backend {
        manager: None,
        outputs: BTreeMap::new(),
        tx,
    };
    queue.roundtrip(&mut state)?;
    if state.manager.is_none() {
        return Err("zdwl_ipc_manager_v2 global missing".into());
    }
    queue.roundtrip(&mut state)?;
    let (wake_tx, wake_rx) = std::os::unix::net::UnixStream::pair()?;
    use std::io::Write;
    std::thread::spawn(move || {
        let mut wake_tx = wake_tx;
        for id in rx {
            if wake_tx.write_all(&[id]).is_err() {
                break;
            }
        }
    });
    use std::io::Read;
    use std::os::fd::AsRawFd;
    loop {
        queue.dispatch_pending(&mut state)?;
        conn.flush()?;
        let Some(guard) = queue.prepare_read() else {
            continue;
        };
        let mut fds = [
            libc::pollfd {
                fd: conn.backend().poll_fd().as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            },
            libc::pollfd {
                fd: wake_rx.as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            },
        ];
        let result = unsafe { libc::poll(fds.as_mut_ptr(), 2, -1) };
        if result < 0 {
            return Err(std::io::Error::last_os_error().into());
        }
        if fds[0].revents != 0 {
            guard.read()?;
        } else {
            drop(guard);
        }
        if fds[1].revents != 0 {
            let mut byte = [0];
            let mut reader = &wake_rx;
            reader.read_exact(&mut byte)?;
            let o = state
                .outputs
                .values()
                .find(|o| o.active)
                .ok_or("no selected DWL output")?;
            if let Some(ipc) = &o.ipc {
                ipc.set_tags(1 << (byte[0] - 1), 1);
            }
        }
    }
}
