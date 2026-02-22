Azure

忘了从哪看到的了，反正用了很久，挺稳定

 点我展开代码
import base64
import hashlib
import hmac
import html
import json
import logging
import time
import uuid
from datetime import datetime
from urllib.parse import quote
import requests
from tenacity import retry, wait_exponential, stop_after_attempt

logger = logging.getLogger(__name__)

# 常量定义
ENDPOINT_URL = "https://dev.microsofttranslator.com/apps/endpoint?api-version=1.0"
VOICES_LIST_URL = "https://eastus.api.speech.microsoft.com/cognitiveservices/voices/list"
USER_AGENT = "okhttp/4.5.0"
CLIENT_VERSION = "4.0.530a 5fe1dc6c"
USER_ID = "0f04d16a175c411e"
HOME_GEOGRAPHIC_REGION = "zh-Hans-CN"
CLIENT_TRACE_ID = "aab069b9-70a7-4844-a734-96cd78d94be9"
VOICE_DECODE_KEY = "oik6PdDdMnOXemTbwvMn9de/h9lFnfBaCWbGMMZqqoSaQaqUOqjVGm5NqsmjcBI1x+sS9ugjB55HEJWRiFXYFw=="
DEFAULT_VOICE_NAME = "zh-CN-XiaoxiaoMultilingualNeural"
DEFAULT_RATE = "0"
DEFAULT_PITCH = "0"
DEFAULT_OUTPUT_FORMAT = "audio-24khz-48kbitrate-mono-mp3"
DEFAULT_STYLE = "general"

endpoint = None
expired_at = None
voice_list_cache = None

def get_endpoint(proxies=None):
    signature = sign(ENDPOINT_URL)
    headers = {
        "Accept-Language": "zh-Hans",
        "X-ClientVersion": CLIENT_VERSION,
        "X-UserId": USER_ID,
        "X-HomeGeographicRegion": HOME_GEOGRAPHIC_REGION,
        "X-ClientTraceId": CLIENT_TRACE_ID,
        "X-MT-Signature": signature,
        "User-Agent": USER_AGENT,
        "Content-Type": "application/json; charset=utf-8",
        "Content-Length": "0",
        "Accept-Encoding": "gzip",
    }

    response = requests.post(ENDPOINT_URL, headers=headers, proxies=proxies)
    response.raise_for_status()
    return response.json()


def sign(url_str):
    u = url_str.split("://")[1]
    encoded_url = quote(u, safe='')
    uuid_str = str(uuid.uuid4()).replace("-", "")
    formatted_date = datetime.utcnow().strftime(
        "%a, %d %b %Y %H:%M:%S").lower() + "gmt"
    bytes_to_sign = f"MSTranslatorAndroidApp{encoded_url}{formatted_date}{uuid_str}".lower().encode('utf-8')

    decode = base64.b64decode(VOICE_DECODE_KEY)
    hmac_sha256 = hmac.new(decode, bytes_to_sign, hashlib.sha256)
    secret_key = hmac_sha256.digest()
    sign_base64 = base64.b64encode(secret_key).decode()

    return f"MSTranslatorAndroidApp::{sign_base64}::{formatted_date}::{uuid_str}"


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=5))
def get_voice(text, voice_name="", rate="", pitch="", output_format="", style="", proxies=None):
    global endpoint, expired_at, client_id

    current_time = int(time.time())
    if not expired_at or current_time > expired_at - 60:
        endpoint = get_endpoint(proxies)
        jwt = endpoint['t'].split('.')[1]
        decoded_jwt = json.loads(base64.b64decode(jwt + '==').decode('utf-8'))
        expired_at = decoded_jwt['exp']
        seconds_left = expired_at - current_time
        client_id = str(uuid.uuid4())
    else:
        seconds_left = expired_at - current_time

    voice_name = voice_name or DEFAULT_VOICE_NAME
    rate = rate or DEFAULT_RATE
    pitch = pitch or DEFAULT_PITCH
    output_format = output_format or DEFAULT_OUTPUT_FORMAT
    style = style or DEFAULT_STYLE

    endpoint = get_endpoint(proxies)

    url = f"https://{endpoint['r']}.tts.speech.microsoft.com/cognitiveservices/v1"
    headers = {
        "Authorization": endpoint["t"],
        "Content-Type": "application/ssml+xml",
        "X-Microsoft-OutputFormat": output_format,
    }

    ssml = get_ssml(text, voice_name, rate, pitch, style)

    response = requests.post(url, headers=headers, data=ssml.encode(), proxies=proxies)
    response.raise_for_status()
    return response.content


def get_ssml(text, voice_name, rate, pitch, style):
    return f"""
<speak xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="http://www.w3.org/2001/mstts" version="1.0" xml:lang="zh-CN">
<voice name="{voice_name}">
    <mstts:express-as style="{style}" styledegree="1.0" role="default">
        <prosody rate="{rate}%" pitch="{pitch}%">
            {text}
        </prosody>
    </mstts:express-as>
</voice>
</speak>
    """

def get_voice_list():
    """获取可用的语音列表"""
    global voice_list_cache

    # 如果缓存中有值，直接返回缓存的结果
    if voice_list_cache is not None:
        return voice_list_cache

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36 Edg/107.0.1418.26",
        "X-Ms-Useragent": "SpeechStudio/2021.05.001",
        "Content-Type": "application/json",
        "Origin": "https://azure.microsoft.com",
        "Referer": "https://azure.microsoft.com"
    }

    try:
        response = requests.get(VOICES_LIST_URL, headers=headers)
        response.raise_for_status()
        result = response.json()

        # 将结果存储到缓存中
        voice_list_cache = result

        return result
    except requests.exceptions.RequestException as e:
        logger.error(f"获取语音列表失败: {e}")
        return None
 支持的音色很多，我爱用的
"voices": [
        {
            "id": 2,
            "name": "zh-CN-XiaoxiaoNeural",
            "label": "晓晓",
            "emotions": [
                {
                    "id": 1,
                    "name": "assistant",
                    "label": "助理"
                },
                {
                    "id": 2,
                    "name": "chat",
                    "label": "聊天"
                },
                {
                    "id": 3,
                    "name": "customerservice",
                    "label": "客服"
                },
                {
                    "id": 4,
                    "name": "newscast",
                    "label": "新闻播报"
                },
                {
                    "id": 5,
                    "name": "affectionate",
                    "label": "深情"
                },
                {
                    "id": 6,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 7,
                    "name": "calm",
                    "label": "平静"
                },
                {
                    "id": 8,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 9,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 10,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 11,
                    "name": "gentle",
                    "label": "温柔"
                },
                {
                    "id": 12,
                    "name": "lyrical",
                    "label": "抒情"
                },
                {
                    "id": 13,
                    "name": "sad",
                    "label": "悲伤"
                },
                {
                    "id": 14,
                    "name": "serious",
                    "label": "严肃"
                },
                {
                    "id": 15,
                    "name": "poetry-reading",
                    "label": "诗歌朗读"
                },
                {
                    "id": 16,
                    "name": "friendly",
                    "label": "友好"
                },
                {
                    "id": 17,
                    "name": "chat-casual",
                    "label": "随意聊天"
                },
                {
                    "id": 18,
                    "name": "whispering",
                    "label": "耳语"
                },
                {
                    "id": 19,
                    "name": "sorry",
                    "label": "抱歉"
                },
                {
                    "id": 20,
                    "name": "excited",
                    "label": "兴奋"
                }
            ]
        },
        {
            "id": 3,
            "name": "zh-CN-YunxiNeural",
            "label": "云希",
            "emotions": [
                {
                    "id": 21,
                    "name": "narration-relaxed",
                    "label": "轻松叙述"
                },
                {
                    "id": 22,
                    "name": "embarrassed",
                    "label": "尴尬"
                },
                {
                    "id": 23,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 24,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 25,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 26,
                    "name": "serious",
                    "label": "严肃"
                },
                {
                    "id": 27,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 28,
                    "name": "sad",
                    "label": "悲伤"
                },
                {
                    "id": 29,
                    "name": "depressed",
                    "label": "沮丧"
                },
                {
                    "id": 30,
                    "name": "chat",
                    "label": "聊天"
                },
                {
                    "id": 31,
                    "name": "assistant",
                    "label": "助理"
                },
                {
                    "id": 32,
                    "name": "newscast",
                    "label": "新闻播报"
                }
            ]
        },
        {
            "id": 4,
            "name": "zh-CN-YunjianNeural",
            "label": "云健",
            "emotions": [
                {
                    "id": 33,
                    "name": "narration-relaxed",
                    "label": "轻松叙述"
                },
                {
                    "id": 34,
                    "name": "sports-commentary",
                    "label": "体育解说"
                },
                {
                    "id": 35,
                    "name": "sports-commentary-excited",
                    "label": "激情体育解说"
                },
                {
                    "id": 36,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 37,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 38,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 39,
                    "name": "sad",
                    "label": "悲伤"
                },
                {
                    "id": 40,
                    "name": "serious",
                    "label": "严肃"
                },
                {
                    "id": 41,
                    "name": "depressed",
                    "label": "沮丧"
                },
                {
                    "id": 42,
                    "name": "documentary-narration",
                    "label": "纪录片解说"
                }
            ]
        },
        {
            "id": 5,
            "name": "zh-CN-XiaoyiNeural",
            "label": "晓伊",
            "emotions": [
                {
                    "id": 43,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 44,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 45,
                    "name": "affectionate",
                    "label": "深情"
                },
                {
                    "id": 46,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 47,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 48,
                    "name": "sad",
                    "label": "悲伤"
                },
                {
                    "id": 49,
                    "name": "embarrassed",
                    "label": "尴尬"
                },
                {
                    "id": 50,
                    "name": "serious",
                    "label": "严肃"
                },
                {
                    "id": 51,
                    "name": "gentle",
                    "label": "温柔"
                }
            ]
        },
        {
            "id": 6,
            "name": "zh-CN-YunyangNeural",
            "label": "云扬",
            "emotions": [
                {
                    "id": 52,
                    "name": "customerservice",
                    "label": "客服"
                },
                {
                    "id": 53,
                    "name": "narration-professional",
                    "label": "专业解说"
                },
                {
                    "id": 54,
                    "name": "newscast-casual",
                    "label": "休闲新闻"
                }
            ]
        },
        {
            "id": 7,
            "name": "zh-CN-XiaochenNeural",
            "label": "晓辰",
            "emotions": [
                {
                    "id": 55,
                    "name": "livecommercial",
                    "label": "直播带货"
                }
            ]
        },
        {
            "id": 8,
            "name": "zh-CN-XiaochenMultilingualNeural",
            "label": "晓辰 多语言",
            "emotions": []
        },
        {
            "id": 9,
            "name": "zh-CN-XiaohanNeural",
            "label": "晓涵",
            "emotions": [
                {
                    "id": 56,
                    "name": "calm",
                    "label": "平静"
                },
                {
                    "id": 57,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 58,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 59,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 60,
                    "name": "serious",
                    "label": "严肃"
                },
                {
                    "id": 61,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 62,
                    "name": "sad",
                    "label": "悲伤"
                },
                {
                    "id": 63,
                    "name": "gentle",
                    "label": "温柔"
                },
                {
                    "id": 64,
                    "name": "affectionate",
                    "label": "深情"
                },
                {
                    "id": 65,
                    "name": "embarrassed",
                    "label": "尴尬"
                }
            ]
        },
        {
            "id": 10,
            "name": "zh-CN-XiaomengNeural",
            "label": "晓梦",
            "emotions": [
                {
                    "id": 66,
                    "name": "chat",
                    "label": "聊天"
                }
            ]
        },
        {
            "id": 11,
            "name": "zh-CN-XiaomoNeural",
            "label": "晓墨",
            "emotions": [
                {
                    "id": 67,
                    "name": "embarrassed",
                    "label": "尴尬"
                },
                {
                    "id": 68,
                    "name": "calm",
                    "label": "平静"
                },
                {
                    "id": 69,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 70,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 71,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 72,
                    "name": "serious",
                    "label": "严肃"
                },
                {
                    "id": 73,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 74,
                    "name": "sad",
                    "label": "悲伤"
                },
                {
                    "id": 75,
                    "name": "depressed",
                    "label": "沮丧"
                },
                {
                    "id": 76,
                    "name": "affectionate",
                    "label": "深情"
                },
                {
                    "id": 77,
                    "name": "gentle",
                    "label": "温柔"
                },
                {
                    "id": 78,
                    "name": "envious",
                    "label": "羡慕"
                }
            ]
        },
        {
            "id": 12,
            "name": "zh-CN-XiaoqiuNeural",
            "label": "晓秋",
            "emotions": []
        },
        {
            "id": 13,
            "name": "zh-CN-XiaorouNeural",
            "label": "晓柔",
            "emotions": []
        },
        {
            "id": 14,
            "name": "zh-CN-XiaoruiNeural",
            "label": "晓睿",
            "emotions": [
                {
                    "id": 79,
                    "name": "calm",
                    "label": "平静"
                },
                {
                    "id": 80,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 81,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 82,
                    "name": "sad",
                    "label": "悲伤"
                }
            ]
        },
        {
            "id": 15,
            "name": "zh-CN-XiaoshuangNeural",
            "label": "晓双",
            "emotions": [
                {
                    "id": 83,
                    "name": "chat",
                    "label": "聊天"
                }
            ]
        },
        {
            "id": 16,
            "name": "zh-CN-XiaoxiaoDialectsNeural",
            "label": "晓晓 方言",
            "emotions": []
        },
        {
            "id": 17,
            "name": "zh-CN-XiaoxiaoMultilingualNeural",
            "label": "晓晓 多语言",
            "emotions": [
                {
                    "id": 84,
                    "name": "affectionate",
                    "label": "深情"
                },
                {
                    "id": 85,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 86,
                    "name": "empathetic",
                    "label": "富有同理心"
                },
                {
                    "id": 87,
                    "name": "excited",
                    "label": "兴奋"
                },
                {
                    "id": 88,
                    "name": "poetry-reading",
                    "label": "诗歌朗读"
                },
                {
                    "id": 89,
                    "name": "sorry",
                    "label": "抱歉"
                },
                {
                    "id": 90,
                    "name": "story",
                    "label": "讲故事"
                }
            ]
        },
        {
            "id": 18,
            "name": "zh-CN-XiaoyanNeural",
            "label": "晓颜",
            "emotions": []
        },
        {
            "id": 19,
            "name": "zh-CN-XiaoyouNeural",
            "label": "晓悠",
            "emotions": []
        },
        {
            "id": 20,
            "name": "zh-CN-XiaoyuMultilingualNeural",
            "label": "晓宇 多语言",
            "emotions": []
        },
        {
            "id": 21,
            "name": "zh-CN-XiaozhenNeural",
            "label": "晓甄",
            "emotions": [
                {
                    "id": 91,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 92,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 93,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 94,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 95,
                    "name": "sad",
                    "label": "悲伤"
                },
                {
                    "id": 96,
                    "name": "serious",
                    "label": "严肃"
                }
            ]
        },
        {
            "id": 22,
            "name": "zh-CN-YunfengNeural",
            "label": "云枫",
            "emotions": [
                {
                    "id": 97,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 98,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 99,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 100,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 101,
                    "name": "sad",
                    "label": "悲伤"
                },
                {
                    "id": 102,
                    "name": "serious",
                    "label": "严肃"
                },
                {
                    "id": 103,
                    "name": "depressed",
                    "label": "沮丧"
                }
            ]
        },
        {
            "id": 23,
            "name": "zh-CN-YunhaoNeural",
            "label": "云皓",
            "emotions": [
                {
                    "id": 104,
                    "name": "advertisement-upbeat",
                    "label": "活力广告"
                }
            ]
        },
        {
            "id": 24,
            "name": "zh-CN-YunjieNeural",
            "label": "云杰",
            "emotions": []
        },
        {
            "id": 25,
            "name": "zh-CN-YunxiaNeural",
            "label": "云夏",
            "emotions": [
                {
                    "id": 105,
                    "name": "calm",
                    "label": "平静"
                },
                {
                    "id": 106,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 107,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 108,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 109,
                    "name": "sad",
                    "label": "悲伤"
                }
            ]
        },
        {
            "id": 26,
            "name": "zh-CN-YunyeNeural",
            "label": "云野",
            "emotions": [
                {
                    "id": 110,
                    "name": "embarrassed",
                    "label": "尴尬"
                },
                {
                    "id": 111,
                    "name": "calm",
                    "label": "平静"
                },
                {
                    "id": 112,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 113,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 114,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 115,
                    "name": "serious",
                    "label": "严肃"
                },
                {
                    "id": 116,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 117,
                    "name": "sad",
                    "label": "悲伤"
                }
            ]
        },
        {
            "id": 27,
            "name": "zh-CN-YunyiMultilingualNeural",
            "label": "云逸 多语言",
            "emotions": []
        },
        {
            "id": 28,
            "name": "zh-CN-YunzeNeural",
            "label": "云泽",
            "emotions": [
                {
                    "id": 118,
                    "name": "calm",
                    "label": "平静"
                },
                {
                    "id": 119,
                    "name": "fearful",
                    "label": "害怕"
                },
                {
                    "id": 120,
                    "name": "cheerful",
                    "label": "愉快"
                },
                {
                    "id": 121,
                    "name": "disgruntled",
                    "label": "不满"
                },
                {
                    "id": 122,
                    "name": "serious",
                    "label": "严肃"
                },
                {
                    "id": 123,
                    "name": "angry",
                    "label": "愤怒"
                },
                {
                    "id": 124,
                    "name": "sad",
                    "label": "悲伤"
                },
                {
                    "id": 125,
                    "name": "depressed",
                    "label": "沮丧"
                },
                {
                    "id": 126,
                    "name": "documentary-narration",
                    "label": "纪录片解说"
                }
            ]
        },
        {
            "id": 29,
            "name": "zh-CN-YunfanMultilingualNeural",
            "label": "Yunfan Multilingual",
            "emotions": []
        },
        {
            "id": 30,
            "name": "zh-CN-YunxiaoMultilingualNeural",
            "label": "Yunxiao Multilingual",
            "emotions": []
        }
    ],
火山

这个原理是用的火山翻译

 点我展开代码
import logging
import requests

from tenacity import retry, wait_exponential, stop_after_attempt

logger = logging.getLogger(__name__)


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=5))
def get_voice(text: str, voice: str):
    headers = {
        "Accept-Language": "en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7,zh-TW;q=0.6",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Origin": "chrome-extension://klgfhbiooeogdfodpopgppeadghjjemk",
        "Pragma": "no-cache",
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Site": "none",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        "accept": "application/json, text/plain, */*",
        "content-type": "application/json",
    }
    language = None
    try:
        response = requests.post(
            "https://translate.volcengine.com/web/langdetect/v1/",
            headers=headers,
            json={"text": text},
        )
        language = response.json().get("language", None)
    finally:
        pass

    json_data = {
        "text": text,
        "speaker": voice,
    }

    if language is not None:
        json_data["language"] = language

    try:
        response = requests.post(
            "https://translate.volcengine.com/crx/tts/v1/",
            headers=headers,
            json=json_data,
        )
        response.raise_for_status()
    except Exception as e:
        logger.error(e)
        raise Exception(f"火山语音服务 {voice} 出错了。")
    resp = response.json()
    audio = resp.get("audio")
    if audio is None:
        logger.error(resp)
        raise Exception(f"火山语音服务 {voice} 生成失败，请切换音色后再试一次。")
    audio_data = audio.get("data", None)
    if audio_data is None:
        logger.error(resp)
        raise Exception(f"火山语音服务 {voice} 数据生成失败。")

    return audio_data
 支持的音色不多
"voices": [
        {
            "id": 71,
            "name": "zh_female_story",
            "label": "少儿故事 中英混",
            "emotions": []
        },
        {
            "id": 72,
            "name": "zh_female_qingxin",
            "label": "清新女声 中英混",
            "emotions": []
        },
        {
            "id": 73,
            "name": "zh_female_zhubo",
            "label": "女主播 中英混",
            "emotions": []
        },
        {
            "id": 74,
            "name": "zh_male_zhubo",
            "label": "男主播 中英混",
            "emotions": []
        },
        {
            "id": 75,
            "name": "zh_male_xiaoming",
            "label": "影视男解说 中英混",
            "emotions": []
        },
        {
            "id": 76,
            "name": "zh_female_sichuan",
            "label": "四川女声 川英混",
            "emotions": []
        },
        {
            "id": 77,
            "name": "zh_male_rap",
            "label": "嘻哈男歌手 中英混",
            "emotions": []
        },
        {
            "id": 78,
            "name": "en_female_sarah",
            "label": "澳英女声 澳洲英语",
            "emotions": []
        },
        {
            "id": 79,
            "name": "jp_male_satoshi",
            "label": "活力男青年 日语",
            "emotions": []
        },
        {
            "id": 80,
            "name": "jp_female_hana",
            "label": "温柔女声 日语",
            "emotions": []
        }
    ],
edgetts

这个不必多说

 直接用 edge_tts 包即可
import edge_tts
from tenacity import retry, wait_exponential, stop_after_attempt


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=5))
def get_voice(input_text: str, voice: str, rate: str, pitch: int):
    communicate = edge_tts.Communicate(
        input_text,
        voice=voice,
        rate=rate,
        pitch=pitch,
    )

    return communicate
 这个支持的特别多，只列出几个中文的
"voices": [
        {
            "id": 61,
            "name": "zh-CN-XiaoxiaoNeural",
            "label": "晓晓 中文 女",
            "emotions": []
        },
        {
            "id": 62,
            "name": "zh-CN-XiaoyiNeural",
            "label": "晓依 中文 女",
            "emotions": []
        },
        {
            "id": 63,
            "name": "zh-CN-YunjianNeural",
            "label": "云健 中文 男",
            "emotions": []
        },
        {
            "id": 64,
            "name": "zh-CN-YunxiNeural",
            "label": "云希 中文 男",
            "emotions": []
        },
        {
            "id": 65,
            "name": "zh-CN-YunxiaNeural",
            "label": "云夏 中文 男",
            "emotions": []
        },
        {
            "id": 66,
            "name": "zh-CN-YunyangNeural",
            "label": "云扬 中文 男",
            "emotions": []
        },
        {
            "id": 67,
            "name": "zh-CN-liaoning-XiaobeiNeural",
            "label": "晓北 辽宁 女",
            "emotions": []
        },
        {
            "id": 68,
            "name": "zh-CN-shaanxi-XiaoniNeural",
            "label": "晓妮 陕西 女",
            "emotions": []
        }
    ],
