/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 * @flow
 */

import React, { Component } from 'react';
import {
  AppRegistry,
  StyleSheet,
  View,
  Dimensions,
  Platform,
  NativeModules
} from 'react-native';
import { Button, Text, List, ListItem } from 'native-base';
import moment from 'moment';
import Sound from 'react-native-sound';

let {height, width} = Dimensions.get('window');
let RNRecorder = NativeModules.RNRecorder;

export default class IOSVoiceRecorder extends Component {
  state = {
      recording: false,
      stoppedRecording: true,
      finished: false,
      audioPath: '',
      fileName:'',
      hasPermission: undefined,
      listAudio:[],
    };

  prepareRecordingPath() {
    let options = {
      SampleRate: 22050,
      Channels: 1,
      AudioQuality: "Low",
      AudioEncoding: "aac",
    }
    let fileName = moment(new Date()).format('YYYY_MM_DD_HHmmss') + '.aac';
    let audioPath = RNRecorder.NSDocumentDirectoryPath + "/" + fileName;
    console.log("Prepare AudiotPath: "+audioPath);
    this.setState({audioPath: audioPath, fileName: fileName});
    RNRecorder.prepareRecordingAtPath(fileName, options.SampleRate, options.Channels, options.AudioQuality, options.AudioEncoding);
  }

  _record = async () => {
      if (this.state.recording) {
        console.warn('Already recording!');
        return;
      }

      if(this.state.stoppedRecording){
        this.prepareRecordingPath();
      }

      this.setState({recording: true});

      try {
        const filePath = await RNRecorder.startRecording();
      } catch (error) {
        console.error(error);
      }
    }

    _pause = async () => {
      if (!this.state.recording) {
        console.warn('Can\'t pause, not recording!');
        return;
      }

      this.setState({stoppedRecording: true, recording: false});

      try {
        const filePath = await RNRecorder.pauseRecording();
      } catch (error) {
        console.error(error);
      }
    }

    _stop = async () =>  {
      if (!this.state.recording) {
        console.warn('Can\'t stop, not recording!');
        return;
      }

      this.setState({stoppedRecording: true, recording: false});

      try {
        const filePath = await RNRecorder.stopRecording();
        let listAudio = this.state.listAudio.slice();
        listAudio.push({name: this.state.fileName, path: this.state.audioPath});
        this.setState({listAudio: listAudio.slice()});
        console.log("Path: "+this.state.listAudio);
        return filePath;
      } catch (error) {
        console.error(error);
      }
    }


    _play = async (audioPath) => {
      if (this.state.recording) {
        await this._stop();
      }

      // These timeouts are a hacky workaround for some issues with react-native-sound.
      // See https://github.com/zmxv/react-native-sound/issues/89.
      setTimeout(() => {
        console.log("AudioPath: "+audioPath);
        let sound = new Sound(audioPath, '', (error) => {
          if (error) {
            console.log('failed to load the sound', error);
          }
        });

        setTimeout(() => {
          sound.play((success) => {
            if (success) {
              console.log('successfully finished playing');
            } else {
              console.log('playback failed due to audio decoding errors');
            }
          });
        }, 100);
      }, 100);
    }

    _delete = async (filePath) => {
      console.log("Delete");
        try {
          await RNRecorder.deleteSound(filePath);
          let listAudio = this.state.listAudio;
          listAudio = listAudio.filter((item) => {
            return item.path !== filePath;
          });
          this.setState({listAudio: listAudio.slice()});
        } catch (error) {
          console.error(error);
        }
    }

    _getSoundList = async () => {
      try {
        let {soundListResponse} = await RNRecorder.getSoundList();

        let audioList = [];
        for (let i = 0; i < soundListResponse.length; i++) {
          let path = RNRecorder.NSDocumentDirectoryPath + "/" + soundListResponse[i];
          audioList.push({
            name: soundListResponse[i],
            path: path
          })
        }
        this.setState({listAudio: audioList.slice()})
        console.log("Sound List: "+soundListResponse);
      } catch ({code, message}) {
        console.log("Error: "+message);
      }
    }

    componentDidMount() {
      this._getSoundList();
    }
  render() {
    const state = this.state;
    const actionButtonText = this.state.recording ? "Pause" : "Record";
    const renderRow = (item) => (
      <ListItem>
        <View style={{flexDirection:'row', justifyContent:'space-between', width:width*0.9}}>
          <Button onPress={() => this._play(item.path)}>
            <Text>Play</Text>
          </Button>
          <Text>{item.name}</Text>
          <Button onPress={() => this._delete(item.path)}>
            <Text>Delete</Text>
          </Button>
        </View>

      </ListItem>
    );
    return (
        <View style={styles.container}>
            <View style={styles.navbar}>
              <Text style={{color:'white'}}>IOS Recorder</Text>
            </View>
            <View style={styles.recorderContainer}>
              <Button onPress={() => {
                this.state.recording ? this._pause() : this._record();
              }} style={{margin:5, alignSelf:'center'}}>
                <Text>{actionButtonText}</Text>
              </Button>
              <Button onPress={() => {
                this._stop();
              }} style={{margin:5, alignSelf:'center'}}>
                <Text>Stop</Text>
              </Button>
            </View>
            <View style={styles.listRecordContainer}>
              <List
                dataArray = {state.listAudio}
                renderRow = {renderRow}
              />
            </View>
        </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'column',
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  recorderContainer: {
    flex: 1,
    flexDirection: 'column',
    justifyContent:'center',
    alignItems:'center',
    borderBottomWidth:1,
    width:width,
    borderColor:'lightgrey'
  },
  listRecordContainer: {
    flex: 1
  },
  navbar: {
    backgroundColor: 'royalblue',
    justifyContent: 'center',
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 15,
    paddingTop: (Platform.OS === 'ios' ) ? 15 : 0,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.1,
    shadowRadius: 1.5,
    height: height*0.11,
    width: width,
    elevation: 3,
    position: 'relative'
  },
});

AppRegistry.registerComponent('IOSVoiceRecorder', () => IOSVoiceRecorder);
