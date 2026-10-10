use std::{
    io::{BufRead, BufReader, Write},
    os::unix::{
        fs::PermissionsExt,
        net::{UnixDatagram, UnixStream},
    },
    process::{Command, Stdio},
    time::Duration,
};
#[test]
fn readiness_snapshot_and_invalid_workspace() {
    let dir = std::env::temp_dir().join(format!("dwl-helper-test-{}", std::process::id()));
    std::fs::create_dir(&dir).unwrap();
    struct Cleanup(std::path::PathBuf);
    impl Drop for Cleanup {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }
    let _cleanup = Cleanup(dir.clone());
    let eww = dir.join("eww");
    std::fs::write(&eww, "#!/bin/sh\nexit 0\n").unwrap();
    std::fs::set_permissions(&eww, std::fs::Permissions::from_mode(0o755)).unwrap();
    let mut paths = vec![dir.clone()];
    paths.extend(std::env::split_paths(&std::env::var_os("PATH").unwrap()));
    let path = std::env::join_paths(paths).unwrap();
    let notify = UnixDatagram::bind(dir.join("notify")).unwrap();
    notify
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let spawn = || {
        Command::new(env!("CARGO_BIN_EXE_dwl-helper"))
            .arg("daemon")
            .env("DWL_HELPER_SOCKET", dir.join("socket"))
            .env("NOTIFY_SOCKET", dir.join("notify"))
            .env("WAYLAND_DISPLAY", "missing-test-compositor")
            .env("PATH", &path)
            .env("DWL_EWW_CONFIG", &dir)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .unwrap()
    };
    struct Stop(std::process::Child);
    impl Drop for Stop {
        fn drop(&mut self) {
            let _ = self.0.kill();
            let _ = self.0.wait();
        }
    }
    let mut stop = Stop(spawn());
    let mut bytes = [0; 64];
    let len = notify.recv(&mut bytes).unwrap();
    assert_eq!(&bytes[..len], b"READY=1");
    let request = |value: serde_json::Value| {
        let mut stream = UnixStream::connect(dir.join("socket")).unwrap();
        stream
            .set_read_timeout(Some(Duration::from_secs(5)))
            .unwrap();
        writeln!(stream, "{value}").unwrap();
        let mut line = String::new();
        BufReader::new(stream).read_line(&mut line).unwrap();
        serde_json::from_str::<serde_json::Value>(&line).unwrap()
    };
    let state = request(serde_json::json!("watch"));
    assert_eq!(state["desktop"]["workspaces"].as_array().unwrap().len(), 10);
    assert_eq!(
        state["drawers"],
        serde_json::json!({"top":false,"audio":false})
    );
    assert!(request(serde_json::json!({"workspace":{"id":0}}))
        .get("error")
        .is_some());
    // Independent callbacks can deliver content enter before the sensor leave.
    assert_eq!(
        request(serde_json::json!({"drawer":{"drawer":"Top","action":"Enter"}})),
        serde_json::json!({"ok":true})
    );
    assert_eq!(
        request(serde_json::json!({"drawer":{"drawer":"Top","action":"Leave","source":"Sensor"}})),
        serde_json::json!({"ok":true})
    );
    std::thread::sleep(Duration::from_millis(300));
    assert_eq!(request(serde_json::json!("watch"))["drawers"]["top"], true);
    assert_eq!(
        request(serde_json::json!({"drawer":{"drawer":"Top","action":"Leave"}})),
        serde_json::json!({"ok":true})
    );
    std::thread::sleep(Duration::from_millis(300));
    assert_eq!(request(serde_json::json!("watch"))["drawers"]["top"], false);
    let mut duplicate = spawn();
    assert!(!duplicate.wait().unwrap().success());
    assert!(dir.join("socket").exists());
    for signal in [libc::SIGTERM, libc::SIGINT] {
        // Send a process signal; signal-hook owns the daemon's handler.
        assert_eq!(unsafe { libc::kill(stop.0.id() as i32, signal) }, 0);
        assert!(stop.0.wait().unwrap().success());
        assert!(!dir.join("socket").exists());
        stop = Stop(spawn());
        notify.recv(&mut bytes).unwrap();
    }
    stop.0.kill().unwrap();
    stop.0.wait().unwrap();
    assert!(dir.join("socket").exists());
    stop = Stop(spawn());
    notify.recv(&mut bytes).unwrap();
    assert_eq!(request(serde_json::json!("watch"))["drawers"]["top"], false);
    drop(stop);
}
