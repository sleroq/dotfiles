use crate::{AudioCommand, Event};
use libpulse_binding as pulse;
use pulse::{
    callbacks::ListResult,
    context::{introspect::Introspector, subscribe::InterestMaskSet, Context, FlagSet, State},
    mainloop::threaded::Mainloop,
    volume::{ChannelVolumes, Volume},
};
use serde::Serialize;
use std::sync::{mpsc, Arc, Mutex};
#[derive(Clone, Default, Serialize, PartialEq)]
pub struct Audio {
    output: Option<Device>,
    input: Option<Device>,
    outputs: Vec<Device>,
    inputs: Vec<Device>,
    streams: Vec<Stream>,
}
#[derive(Clone, Serialize, PartialEq)]
struct Device {
    id: u32,
    name: String,
    label: String,
    volume: f64,
    muted: bool,
    #[serde(skip)]
    channels: u8,
}
#[derive(Clone, Serialize, PartialEq)]
struct Stream {
    id: u32,
    name: String,
    icon: String,
    volume: f64,
    muted: bool,
    output: u32,
    #[serde(skip)]
    channels: u8,
}
#[derive(Default)]
struct Cache {
    audio: Audio,
    output: Option<String>,
    input: Option<String>,
    pending: u8,
}
fn volume(v: &ChannelVolumes) -> f64 {
    (f64::from(v.avg().0) / f64::from(Volume::NORMAL.0) * 100.).clamp(0., 150.)
}
fn publish(cache: &mut Cache, tx: &mpsc::Sender<Event>) {
    cache.audio.outputs.sort_by_key(|d| d.id);
    cache.audio.inputs.sort_by_key(|d| d.id);
    cache.audio.streams.sort_by_key(|d| d.id);
    cache.audio.output = cache
        .audio
        .outputs
        .iter()
        .find(|d| Some(&d.name) == cache.output.as_ref())
        .cloned();
    cache.audio.input = cache
        .audio
        .inputs
        .iter()
        .find(|d| Some(&d.name) == cache.input.as_ref())
        .cloned();
    let _ = tx.send(Event::Audio(cache.audio.clone()));
}
fn complete(cache: &mut Cache, target: &Arc<Mutex<Cache>>, tx: &mpsc::Sender<Event>) {
    cache.pending -= 1;
    if cache.pending == 0 {
        if let Ok(mut target) = target.lock() {
            target.audio = cache.audio.clone();
            target.output = cache.output.clone();
            target.input = cache.input.clone();
            publish(&mut target, tx);
        }
    }
}
fn refresh(i: &Introspector, target: Arc<Mutex<Cache>>, tx: mpsc::Sender<Event>) {
    let cache = Arc::new(Mutex::new(Cache {
        pending: 4,
        ..Cache::default()
    }));
    let c = cache.clone();
    let t = tx.clone();
    let destination = target.clone();
    i.get_server_info(move |info| {
        if let Ok(mut c) = c.lock() {
            c.output = info.default_sink_name.as_ref().map(|s| s.to_string());
            c.input = info.default_source_name.as_ref().map(|s| s.to_string());
            complete(&mut c, &destination, &t);
        }
    });
    let c = cache.clone();
    let t = tx.clone();
    let destination = target.clone();
    let mut devices = Vec::new();
    i.get_sink_info_list(move |result| match result {
        ListResult::Item(d) => devices.push(Device {
            id: d.index,
            name: d.name.as_deref().unwrap_or("").into(),
            label: d.description.as_deref().unwrap_or("").into(),
            volume: volume(&d.volume),
            muted: d.mute,
            channels: d.volume.len(),
        }),
        ListResult::End => {
            if let Ok(mut c) = c.lock() {
                c.audio.outputs = std::mem::take(&mut devices);
                complete(&mut c, &destination, &t);
            }
        }
        ListResult::Error => {
            let _ = t.send(Event::Error("PulseAudio sink introspection failed".into()));
        }
    });
    let c = cache.clone();
    let t = tx.clone();
    let destination = target.clone();
    let mut devices = Vec::new();
    i.get_source_info_list(move |result| match result {
        ListResult::Item(d) => devices.push(Device {
            id: d.index,
            name: d.name.as_deref().unwrap_or("").into(),
            label: d.description.as_deref().unwrap_or("").into(),
            volume: volume(&d.volume),
            muted: d.mute,
            channels: d.volume.len(),
        }),
        ListResult::End => {
            if let Ok(mut c) = c.lock() {
                c.audio.inputs = std::mem::take(&mut devices);
                complete(&mut c, &destination, &t);
            }
        }
        ListResult::Error => {
            let _ = t.send(Event::Error(
                "PulseAudio source introspection failed".into(),
            ));
        }
    });
    let mut streams = Vec::new();
    i.get_sink_input_info_list(move |result| match result {
        ListResult::Item(d) => streams.push(Stream {
            id: d.index,
            name: d
                .proplist
                .get_str("application.name")
                .or_else(|| d.name.as_ref().map(|s| s.to_string()))
                .unwrap_or_default(),
            icon: d
                .proplist
                .get_str("application.icon_name")
                .unwrap_or_default(),
            volume: volume(&d.volume),
            muted: d.mute,
            output: d.sink,
            channels: d.volume.len(),
        }),
        ListResult::End => {
            if let Ok(mut c) = cache.lock() {
                c.audio.streams = std::mem::take(&mut streams);
                complete(&mut c, &target, &tx);
            }
        }
        ListResult::Error => {
            let _ = tx.send(Event::Error(
                "PulseAudio stream introspection failed".into(),
            ));
        }
    });
}
pub fn start(tx: mpsc::Sender<Event>) -> mpsc::Sender<AudioCommand> {
    let (sender, rx) = mpsc::channel();
    std::thread::spawn(move || {
        if let Err(e) = run(tx.clone(), rx) {
            let _ = tx.send(Event::Error(format!("PulseAudio: {e}")));
        }
    });
    sender
}
fn run(tx: mpsc::Sender<Event>, rx: mpsc::Receiver<AudioCommand>) -> Result<(), String> {
    let mut ml = Mainloop::new().ok_or("cannot create mainloop")?;
    let mut context = Context::new(&ml, "dwl-helper").ok_or("cannot create context")?;
    let (states_tx, states_rx) = mpsc::channel();
    context.set_state_callback(Some(Box::new(move || {
        let _ = states_tx.send(());
    })));
    context
        .connect(None, FlagSet::NOFLAGS, None)
        .map_err(|e| format!("{e:?}"))?;
    ml.start().map_err(|e| format!("{e:?}"))?;
    loop {
        states_rx.recv().map_err(|e| e.to_string())?;
        ml.lock();
        let state = context.get_state();
        ml.unlock();
        match state {
            State::Ready => break,
            State::Failed | State::Terminated => return Err("connection failed".into()),
            _ => {}
        }
    }
    ml.lock();
    let cache = Arc::new(Mutex::new(Cache::default()));
    let introspector = context.introspect();
    let subscription_introspector = context.introspect();
    let c = cache.clone();
    let t = tx.clone();
    context.set_subscribe_callback(Some(Box::new(move |_, _, _| {
        refresh(&subscription_introspector, c.clone(), t.clone())
    })));
    context.subscribe(
        InterestMaskSet::SINK
            | InterestMaskSet::SOURCE
            | InterestMaskSet::SINK_INPUT
            | InterestMaskSet::SERVER,
        |ok| {
            if !ok {
                eprintln!("dwl-helper: PulseAudio subscription failed");
            }
        },
    );
    refresh(&introspector, cache.clone(), tx.clone());
    ml.unlock();
    for command in rx {
        ml.lock();
        let result = apply(&mut context, &cache, command, tx.clone());
        ml.unlock();
        if let Err(e) = result {
            let _ = tx.send(Event::Error(e));
        }
    }
    ml.stop();
    Ok(())
}
fn apply(
    context: &mut Context,
    cache: &Arc<Mutex<Cache>>,
    command: AudioCommand,
    tx: mpsc::Sender<Event>,
) -> Result<(), String> {
    let c = cache.lock().map_err(|e| e.to_string())?;
    let a = &c.audio;
    let mut i = context.introspect();
    let callback = Box::new(move |ok: bool| {
        if !ok {
            let _ = tx.send(Event::Error("PulseAudio control failed".into()));
        }
    }) as Box<dyn FnMut(bool)>;
    fn levels(channels: u8, percent: f64) -> ChannelVolumes {
        let mut v = ChannelVolumes::default();
        v.set(
            channels,
            Volume((percent.clamp(0., 150.) / 100. * f64::from(Volume::NORMAL.0)).round() as u32),
        );
        v
    }
    match command {
        AudioCommand::OutputDefault { name } => {
            context.set_default_sink(&name, callback);
        }
        AudioCommand::InputDefault { name } => {
            context.set_default_source(&name, callback);
        }
        AudioCommand::OutputVolume { percent } => {
            let d = a.output.as_ref().ok_or("default output unavailable")?;
            i.set_sink_volume_by_index(d.id, &levels(d.channels, percent), Some(callback));
        }
        AudioCommand::InputVolume { percent } => {
            let d = a.input.as_ref().ok_or("default input unavailable")?;
            i.set_source_volume_by_index(d.id, &levels(d.channels, percent), Some(callback));
        }
        AudioCommand::OutputMute => {
            let d = a.output.as_ref().ok_or("default output unavailable")?;
            i.set_sink_mute_by_index(d.id, !d.muted, Some(callback));
        }
        AudioCommand::InputMute => {
            let d = a.input.as_ref().ok_or("default input unavailable")?;
            i.set_source_mute_by_index(d.id, !d.muted, Some(callback));
        }
        AudioCommand::StreamVolume { id, percent } => {
            let d = a
                .streams
                .iter()
                .find(|s| s.id == id)
                .ok_or("stream unavailable")?;
            i.set_sink_input_volume(id, &levels(d.channels, percent), Some(callback));
        }
        AudioCommand::StreamMute { id } => {
            let d = a
                .streams
                .iter()
                .find(|s| s.id == id)
                .ok_or("stream unavailable")?;
            i.set_sink_input_mute(id, !d.muted, Some(callback));
        }
        AudioCommand::StreamOutput { stream_id, sink_id } => {
            i.move_sink_input_by_index(stream_id, sink_id, Some(callback));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn introspection_publishes_only_after_all_four_callbacks() {
        let target = Arc::new(Mutex::new(Cache::default()));
        let mut batch = Cache {
            pending: 4,
            output: Some("speakers".into()),
            ..Cache::default()
        };
        batch.audio.outputs.push(Device {
            id: 1,
            name: "speakers".into(),
            label: "Speakers".into(),
            volume: 50.,
            muted: false,
            channels: 2,
        });
        let (tx, rx) = mpsc::channel();
        for _ in 0..3 {
            complete(&mut batch, &target, &tx);
            assert!(rx.try_recv().is_err());
        }
        complete(&mut batch, &target, &tx);
        let Event::Audio(audio) = rx.try_recv().unwrap() else {
            panic!("expected audio snapshot");
        };
        assert_eq!(audio.output.as_ref().map(|d| d.id), Some(1));
        assert!(rx.try_recv().is_err());
    }
}
