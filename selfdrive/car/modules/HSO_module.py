# human steer override module

class HSOController:
    def __init__(self):
        self.human_control = False
        self.frame_humanSteered = 0

    def update_stat(self, CS, enabled, actuators, frame):
        human_control = False

        if CS.enableHSO and enabled:
            if CS.HSOSteeringPressed:
                self.frame_humanSteered = frame

            # Once HSO has started, keep it active while the blinker remains on.
            if CS.turnSignalStalkState > 0 and \
            frame - self.frame_humanSteered < (CS.hsoNumbPeriod * 100):
                self.frame_humanSteered = frame

            if frame - self.frame_humanSteered < (CS.hsoNumbPeriod * 100):
                human_control = True

        self.human_control = human_control
        return human_control and enabled