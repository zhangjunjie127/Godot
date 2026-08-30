from pathlib import Path
import wave

import numpy as np


SAMPLE_RATE = 22050
DURATION_SECONDS = 40
RANDOM_SEED = 20260830


def smooth_noise(values: np.ndarray, window: int) -> np.ndarray:
    left = window // 2
    right = window - left - 1
    padded = np.pad(values, (left, right), mode="wrap")
    cumulative = np.concatenate(([0.0], np.cumsum(padded, dtype=np.float64)))
    return (cumulative[window:] - cumulative[:-window]) / window


def seamless_tail(samples: np.ndarray, seconds: float = 2.0) -> None:
    length = round(seconds * SAMPLE_RATE)
    blend = np.linspace(0.0, 1.0, length, endpoint=True)[:, None]
    samples[-length:] = samples[-length:] * (1.0 - blend) + samples[:length] * blend


def write_wav(path: Path, samples: np.ndarray) -> None:
    peak = max(float(np.max(np.abs(samples))), 1.0e-6)
    pcm = np.clip(samples / peak * 0.82, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def generate_wind(rng: np.random.Generator, sample_count: int) -> np.ndarray:
    channels = []
    for _channel in range(2):
        noise = rng.standard_normal(sample_count)
        body = smooth_noise(noise, 180)
        air = smooth_noise(noise, 34)
        gust_source = rng.standard_normal(sample_count)
        gusts = smooth_noise(gust_source, SAMPLE_RATE * 2)
        gusts -= gusts.min()
        gusts /= max(float(gusts.max()), 1.0e-6)
        channels.append((body * 0.78 + air * 0.22) * (0.45 + gusts * 0.55))
    wind = np.column_stack(channels)
    seamless_tail(wind)
    return wind


def add_bird_call(
    samples: np.ndarray,
    rng: np.random.Generator,
    start_seconds: float,
    gain: float,
) -> None:
    pan = rng.uniform(-0.85, 0.85)
    left_gain = np.sqrt((1.0 - pan) * 0.5)
    right_gain = np.sqrt((1.0 + pan) * 0.5)
    chirp_count = int(rng.integers(2, 6))
    cursor = round(start_seconds * SAMPLE_RATE)
    for chirp_index in range(chirp_count):
        duration = rng.uniform(0.08, 0.19)
        count = round(duration * SAMPLE_RATE)
        if cursor + count >= samples.shape[0]:
            return
        progress = np.linspace(0.0, 1.0, count, endpoint=False)
        base_frequency = rng.uniform(1750.0, 3400.0)
        sweep = rng.uniform(450.0, 1500.0) * (1.0 if chirp_index % 2 == 0 else -0.55)
        frequency = base_frequency + sweep * np.sin(progress * np.pi)
        phase = np.cumsum(frequency) * (2.0 * np.pi / SAMPLE_RATE)
        envelope = np.sin(progress * np.pi) ** 1.8
        flutter = 0.82 + 0.18 * np.sin(progress * np.pi * rng.uniform(6.0, 11.0))
        chirp = (np.sin(phase) + 0.22 * np.sin(phase * 2.03)) * envelope * flutter * gain
        samples[cursor : cursor + count, 0] += chirp * left_gain
        samples[cursor : cursor + count, 1] += chirp * right_gain
        cursor += count + round(rng.uniform(0.05, 0.16) * SAMPLE_RATE)


def generate_birds(rng: np.random.Generator, sample_count: int) -> np.ndarray:
    birds = np.zeros((sample_count, 2), dtype=np.float64)
    position = 1.2
    while position < DURATION_SECONDS - 2.0:
        add_bird_call(birds, rng, position, rng.uniform(0.16, 0.34))
        position += rng.uniform(2.0, 4.8)
    position = 3.0
    while position < DURATION_SECONDS - 2.0:
        add_bird_call(birds, rng, position, rng.uniform(0.05, 0.11))
        position += rng.uniform(4.5, 8.0)
    seamless_tail(birds, 1.0)
    return birds


def main() -> None:
    rng = np.random.default_rng(RANDOM_SEED)
    sample_count = SAMPLE_RATE * DURATION_SECONDS
    project = Path(__file__).resolve().parents[1]
    output_dir = project / "assets" / "weather" / "day"
    write_wav(output_dir / "gentle_wind.wav", generate_wind(rng, sample_count))
    write_wav(output_dir / "birds_ambience.wav", generate_birds(rng, sample_count))
    print(output_dir)


if __name__ == "__main__":
    main()
