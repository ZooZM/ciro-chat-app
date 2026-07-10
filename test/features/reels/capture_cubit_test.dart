import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/capture_cubit.dart';

void main() {
  group('CaptureCubit (v5, FR-079/FR-080)', () {
    blocTest<CaptureCubit, CaptureState>(
      'requestPermissions() emits permissionDenied when either permission is refused',
      build: () => CaptureCubit(
        requestCameraPermission: () async => true,
        requestMicrophonePermission: () async => false,
      ),
      act: (cubit) => cubit.requestPermissions(),
      expect: () => [
        const CaptureState(status: CaptureStatus.permissionDenied),
      ],
    );

    blocTest<CaptureCubit, CaptureState>(
      'requestPermissions() clears a prior permissionDenied state back to idle on success',
      build: () => CaptureCubit(
        requestCameraPermission: () async => true,
        requestMicrophonePermission: () async => true,
      ),
      seed: () => const CaptureState(status: CaptureStatus.permissionDenied),
      act: (cubit) => cubit.requestPermissions(),
      expect: () => [
        const CaptureState(status: CaptureStatus.idle),
      ],
    );

    blocTest<CaptureCubit, CaptureState>(
      'setCap updates the selected duration cap while idle',
      build: () => CaptureCubit(),
      act: (cubit) => cubit.setCap(const Duration(seconds: 15)),
      expect: () => [
        const CaptureState(cap: Duration(seconds: 15)),
      ],
    );

    test('setCap is a no-op while recording', () {
      fakeAsync((async) {
        final cubit = CaptureCubit();
        cubit.startRecording(onCapReached: () {});
        cubit.setCap(const Duration(seconds: 15));
        expect(cubit.state.cap, const Duration(seconds: 60));
        cubit.close();
      });
    });

    test('auto-stop: onCapReached fires exactly once when elapsed reaches the cap', () {
      fakeAsync((async) {
        var capReachedCount = 0;
        final cubit = CaptureCubit();
        cubit.setCap(const Duration(seconds: 15));
        cubit.startRecording(onCapReached: () => capReachedCount++);

        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();

        expect(capReachedCount, 1);
        expect(cubit.state.elapsed, const Duration(seconds: 15));
        expect(cubit.state.isRecording, isTrue); // the screen must call stopRecording itself

        cubit.close();
      });
    });

    test('the elapsed ticker stops once the cap is reached (no further emits)', () {
      fakeAsync((async) {
        final cubit = CaptureCubit();
        cubit.setCap(const Duration(seconds: 15));
        cubit.startRecording(onCapReached: () {});
        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();
        final elapsedAtCap = cubit.state.elapsed;

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(cubit.state.elapsed, elapsedAtCap);
        cubit.close();
      });
    });

    test('stopRecording after >=1s emits captured with the given path', () {
      fakeAsync((async) {
        final cubit = CaptureCubit();
        cubit.startRecording(onCapReached: () {});
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        cubit.stopRecording('/tmp/clip.mp4');

        expect(cubit.state.status, CaptureStatus.captured);
        expect(cubit.state.videoPath, '/tmp/clip.mp4');
        cubit.close();
      });
    });

    test('a sub-1s take is discarded — idle with an incremented discardCount, no videoPath', () {
      fakeAsync((async) {
        final cubit = CaptureCubit();
        cubit.startRecording(onCapReached: () {});
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();

        cubit.stopRecording('/tmp/too_short.mp4');

        expect(cubit.state.status, CaptureStatus.idle);
        expect(cubit.state.videoPath, isNull);
        expect(cubit.state.discardCount, 1);
        cubit.close();
      });
    });

    test('stopRecording with a null path (failed platform stop) discards regardless of elapsed', () {
      fakeAsync((async) {
        final cubit = CaptureCubit();
        cubit.startRecording(onCapReached: () {});
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        cubit.stopRecording(null);

        expect(cubit.state.status, CaptureStatus.idle);
        expect(cubit.state.videoPath, isNull);
        expect(cubit.state.discardCount, 1);
        cubit.close();
      });
    });

    test('lifecycle pause routes through the same stop logic (binding rule 13)', () {
      fakeAsync((async) {
        final cubit = CaptureCubit();
        cubit.startRecording(onCapReached: () {});
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // The widget's WidgetsBindingObserver calls stopRecording with
        // whatever the platform stop produced (or null on failure) —
        // exercised here directly since the observer itself needs a real
        // CameraController to test meaningfully.
        cubit.stopRecording('/tmp/paused.mp4');

        expect(cubit.state.status, CaptureStatus.captured);
        cubit.close();
      });
    });

    test('stopRecording is idempotent — a manual/auto-stop race cannot overwrite a captured clip', () {
      fakeAsync((async) {
        final cubit = CaptureCubit();
        cubit.startRecording(onCapReached: () {});
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        cubit.stopRecording('/tmp/clip.mp4'); // first (real) stop → captured
        expect(cubit.state.status, CaptureStatus.captured);
        expect(cubit.state.videoPath, '/tmp/clip.mp4');

        // A racing late stop (e.g. the cap auto-stop firing after a manual
        // stop) must be a no-op — never discard the already-captured clip.
        cubit.stopRecording(null);
        expect(cubit.state.status, CaptureStatus.captured);
        expect(cubit.state.videoPath, '/tmp/clip.mp4');
        expect(cubit.state.discardCount, 0);
        cubit.close();
      });
    });

    blocTest<CaptureCubit, CaptureState>(
      'reset() returns to idle and clears the captured path',
      build: () => CaptureCubit(),
      seed: () => const CaptureState(status: CaptureStatus.captured, videoPath: '/tmp/x.mp4'),
      act: (cubit) => cubit.reset(),
      expect: () => [
        const CaptureState(status: CaptureStatus.idle),
      ],
    );
  });
}
