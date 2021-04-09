import Config

config :elevator_project,
  # Project info
  project_num_elevators:          3,
  project_min_floor:              0,
  project_num_floors:             4,
  project_cookie_name:            :ttk4145_30,

  # Sending
  ack_timeout_time_ms:            200,
  resend_max_counter:             10,

  # Master
  master_update_active_time_ms:   100,
  master_timeout_active_ms:       1000,
  master_timeout_elevator_ms:     2000,

  # Elevator
<<<<<<< HEAD
  
=======
>>>>>>> a6d8e88962173c0386b4abffc73a2bb200c23fb4
  elevator_restart_time_ms:       2000,
  elevator_timeout_door_ms:       3000,
  elevator_timeout_moving_ms:     5000,
  elevator_update_status_time_ms: 250,
  elevator_timeout_init_ms:       5000,

  # Panel
  panel_ack_timeout: 800,
  panel_checker_timeout: 1000,
  panel_checker_sleep: 200
