{ ... }:

{
  programs.mangohud = {
    enable = true;
    settings = {
      legacy_layout = false;
      gpu_stats = true;
      gpu_load_change = true;
      gpu_temp = true;
      gpu_power = true;
      cpu_stats = true;
      cpu_load_change = true;
      cpu_temp = true;
      fps = true;
      fps_color_change = true;
      fps_metrics = "avg,0.01";
      toggle_logging = "Shift_L+F2";
      toggle_hud_position = "Shift_R+F11";
      fps_limit_method = "late";
      toggle_fps_limit = "Shift_L+F1";
      horizontal = true;
      horizontal_stretch = 0;
      background_alpha = 0.2;
      position = "top-left";
      table_columns = 4;
      toggle_hud = "Shift_R+F12";
      font_size = 20;
      gpu_color = "2e9762";
      cpu_color = "2e97cb";
      fps_value = "30,60";
      fps_color = "cc0000,ffaa7f,92e79a";
      gpu_load_value = "60,90";
      gpu_load_color = "92e79a,ffaa7f,cc0000";
      cpu_load_value = "60,90";
      cpu_load_color = "92e79a,ffaa7f,cc0000";
      background_color = "000000";
      frametime_color = "00ff00";
      vram_color = "ad64c1";
      ram_color = "c26693";
      wine_color = "eb5b5b";
      engine_color = "eb5b5b";
      text_color = "ffffff";
      media_player_color = "ffffff";
      network_color = "e07b85";
      battery_color = "92e79a";
      media_player_format = "{title};{artist};{album}";
    };
  };
}