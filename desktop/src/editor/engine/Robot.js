import Prims from './Prims';
import {isAndroid,isTablet} from '../../utils/lib';

export default class Robot {

  static init(){

    Robot.robot = {};
    Robot.robot.drivers = []; // threads running a robot block, the last one drives

  }

  static robot_send_power_command(robot_version, left_speed, right_speed){

    let left_speed_hex_string = left_speed.toString(16);
    let right_speed_hex_string = right_speed.toString(16);


    if (!isTablet){



    let url = `http://127.0.0.1:9876/txt/def/${robot_version}/rob_power/${left_speed_hex_string}/${right_speed_hex_string}`;

  //  console.log("[Engine::Robot.js::robot_send_power_command::url1:] " + url);

     var xhr = new XMLHttpRequest();
     xhr.open('GET', url, true);

     xhr.onload = function(){
        if(this.status == 200){
           //  alert("sucess");
        }
        else{
           var error = new Error(this.statusText);
           error.code = this.status;
           alert("error:" + error);
        }
    };

    xhr.onerror = function() {
    //  alert("Network error");
    };

    xhr.send();

//    console.log("[Engine::Robot.js::robot_send_power_command::url2:] " + url);
  }else{




      var result = AndroidInterface.setMotorPower(left_speed,right_speed);
      //alert(result);
  }

    }


static robot_send_power_command_desktop(robot_version, left_speed, right_speed){

  return new Promise(function(resolve, reject) {
    let url = `http://127.0.0.1:9876/txt/def/${robot_version}/rob_power/${left_speed}/${right_speed}`;

    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);

    xhr.onload = function() {
    if (this.status == 200) {
       if (resolve)
            resolve(this.response);
       }
       else {
            var error = new Error(this.statusText);
            error.code = this.status;
            if (reject)
            reject(error);
       }
    };

    xhr.onerror = function() {
       reject(new Error("Network Error"));
    };

    xhr.send();

    console.log("[Engine::Robot.js::robot_send_power_command::url:] " + url);

  });
}



    /*** Robot Block start ***/
   static Robot_forward(strip){
      Robot.drive(strip, false, false);
   }

   static Robot_back(strip){
      Robot.drive(strip, true, true);
   }

   static Robot_left(strip){
      Robot.drive(strip, true, false);
   }

   static Robot_right(strip){
      Robot.drive(strip, false, true);
   }

   static Robot_stop(strip){
      Robot.robot.drivers.slice().forEach(function(driver){
         Robot.finish(driver);
      });
      Robot.robot_send_power_command(strip.robot_version, "00", "00");
      Prims.DoNextBlock(strip);
   }

   static drive(strip, reverse_left, reverse_right){
      let power_in_percent = (strip.robot_version != 3) ? 30 : 100; //Мощность в процетах.
      let power = Math.round(power_in_percent * 0.63);
      let execution_time = Number(strip.thisblock.getArgValue()) * 1000 / 5;

      if (execution_time == 0){
         Prims.DoNextBlock(strip);
         return;
      }

      // Adding 64 reverses a motor. robot_version of a running thread changes when another
      // script starts, so the command keeps its own.
      let command = {
         robot_version: strip.robot_version,
         power_left: reverse_left ? power + 64 : power,
         power_right: reverse_right ? power + 64 : power
      };

      strip.robot_command = command;
      Robot.robot.drivers.push(strip);

      // The block ends here, not by waitTimer, which counts ticks. Set before the repeat timer
      // so that no power command follows the stop command.
      strip.waitTimer = execution_time;
      command.finish_timer = setTimeout(function(){
         Robot.finish(strip);
      }, execution_time);

      Robot.send_command(command);
      command.repeat_timer = setInterval(function(){
         if (Robot.robot.drivers[Robot.robot.drivers.length - 1] == strip){
            Robot.send_command(command);
         }
      }, 200);
   }

   static send_command(command){
      Robot.robot_send_power_command(command.robot_version, command.power_left, command.power_right);
   }

   static finish(strip){
      Robot.cancel(strip);
      Prims.DoNextBlock(strip);
   }

   // Ends the thread's robot block, if any. Called when a block finishes and when its thread stops.
   static cancel(strip){
      let command = strip.robot_command;

      if (!command){
         return;
      }

      strip.robot_command = undefined;
      clearTimeout(command.finish_timer);
      clearInterval(command.repeat_timer);
      Robot.robot.drivers.splice(Robot.robot.drivers.indexOf(strip), 1);

      if (Robot.robot.drivers.length == 0){
         Robot.robot_send_power_command(command.robot_version, "00", "00");
      }
   }
    /*** Robot Block end ***/
}
