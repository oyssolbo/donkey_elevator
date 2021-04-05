import Config

config :elevator_project,
  # Project info
  project_num_elevators:          3,
  project_min_floor:              0,
  project_num_floors:             4,
  project_cookie_name:            :ttk4145_30,

  # Master
  master_update_active_time_ms:   100,
  master_timeout_active_ms:       1000,
  master_timeout_elevator_ms:     1000,

  # Elevator
  elevator_timeout_door_ms:       3000,
  elevator_timeout_moving_ms:     5000,
  elevator_update_status_time_ms: 200,
  elevator_timeout_init_ms:       5000
