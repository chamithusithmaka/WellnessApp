// offline_response_service.dart - Provides hardcoded empathetic responses
// when the device is offline and Gemini API is unreachable

import 'dart:math';

class OfflineResponseService {
  static final _random = Random();

  /// Get an empathetic offline response based on the user's message keywords
  static String getResponse(String userMessage) {
    final lowerMsg = userMessage.toLowerCase();

    // Check for crisis/self-harm keywords first — always provide hotline
    if (_containsAny(lowerMsg, _crisisKeywords)) {
      return _pickRandom(_crisisResponses);
    }

    // Match emotional categories
    if (_containsAny(lowerMsg, _sadKeywords)) {
      return _pickRandom(_sadResponses);
    }
    if (_containsAny(lowerMsg, _anxiousKeywords)) {
      return _pickRandom(_anxiousResponses);
    }
    if (_containsAny(lowerMsg, _angryKeywords)) {
      return _pickRandom(_angryResponses);
    }
    if (_containsAny(lowerMsg, _stressedKeywords)) {
      return _pickRandom(_stressedResponses);
    }
    if (_containsAny(lowerMsg, _lonelyKeywords)) {
      return _pickRandom(_lonelyResponses);
    }
    if (_containsAny(lowerMsg, _happyKeywords)) {
      return _pickRandom(_happyResponses);
    }
    if (_containsAny(lowerMsg, _gratitudeKeywords)) {
      return _pickRandom(_gratitudeResponses);
    }
    if (_containsAny(lowerMsg, _sleepKeywords)) {
      return _pickRandom(_sleepResponses);
    }
    if (_containsAny(lowerMsg, _greetingKeywords)) {
      return _pickRandom(_greetingResponses);
    }

    // Default supportive response
    return _pickRandom(_defaultResponses);
  }

  // ==================== Keyword Lists ====================

  static const _crisisKeywords = [
    'suicidal', 'suicide', 'kill myself', 'end my life', 'self-harm',
    'self harm', 'hurt myself', 'don\'t want to live', 'want to die',
    'no reason to live', 'ending it all',
  ];

  static const _sadKeywords = [
    'sad', 'depressed', 'unhappy', 'crying', 'tears', 'miserable',
    'heartbroken', 'grief', 'grieving', 'loss', 'lost someone',
    'devastated', 'empty', 'numb', 'hopeless', 'down',
  ];

  static const _anxiousKeywords = [
    'anxious', 'anxiety', 'worried', 'worry', 'nervous', 'panic',
    'panic attack', 'scared', 'fear', 'terrified', 'overthinking',
    'can\'t stop thinking', 'racing thoughts', 'restless', 'uneasy',
  ];

  static const _angryKeywords = [
    'angry', 'mad', 'furious', 'rage', 'frustrated', 'irritated',
    'annoyed', 'pissed', 'hate', 'resentment', 'bitter',
  ];

  static const _stressedKeywords = [
    'stressed', 'stress', 'overwhelmed', 'pressure', 'burnout',
    'burnt out', 'exhausted', 'drained', 'tired', 'overloaded',
    'too much', 'can\'t handle', 'breaking point',
  ];

  static const _lonelyKeywords = [
    'lonely', 'alone', 'isolated', 'no friends', 'no one cares',
    'nobody', 'disconnected', 'left out', 'abandoned', 'rejected',
  ];

  static const _happyKeywords = [
    'happy', 'great', 'amazing', 'wonderful', 'excited', 'joy',
    'good day', 'fantastic', 'blessed', 'thrilled', 'grateful',
    'feeling good', 'awesome', 'excellent', 'cheerful',
  ];

  static const _gratitudeKeywords = [
    'thank you', 'thanks', 'appreciate', 'helpful', 'helped me',
    'you\'re great', 'you help', 'means a lot',
  ];

  static const _sleepKeywords = [
    'can\'t sleep', 'insomnia', 'sleep', 'nightmare', 'nightmares',
    'restless night', 'waking up', 'trouble sleeping',
  ];

  static const _greetingKeywords = [
    'hello', 'hi', 'hey', 'good morning', 'good evening',
    'good afternoon', 'how are you', 'what\'s up',
  ];

  // ==================== Response Lists ====================

  static const _crisisResponses = [
    "I hear you, and I'm really glad you reached out 💙\n\nYou're not alone in this. Please reach out to the 988 Suicide & Crisis Lifeline — call or text 988. They're available 24/7 and can help.\n\nI'm here for you, and your life matters.",
    "Thank you for trusting me with this 💙\n\nPlease contact the 988 Suicide & Crisis Lifeline right now — call or text 988. You deserve support from someone who can truly help.\n\nYou matter, and things can get better.",
    "I care about you, and what you're feeling is important 💙\n\nPlease reach out to the 988 Suicide & Crisis Lifeline (call or text 988) — they're trained to help with exactly what you're going through.\n\nYou don't have to face this alone.",
  ];

  static const _sadResponses = [
    "I'm sorry you're feeling this way 💙\n\nIt's okay to feel sad — your emotions are valid. Sometimes just acknowledging sadness is the first step to healing.\n\nWould you like to talk more about what's making you feel this way?",
    "I hear you, and I want you to know that sadness is a natural part of being human 💙\n\nBe gentle with yourself right now. You don't have to have all the answers today.\n\nWhat's weighing on your heart?",
    "That sounds really tough, and I'm here for you 💙\n\nSometimes the bravest thing we can do is let ourselves feel. You don't have to push through this alone.\n\nTake a deep breath. Is there something specific that triggered this feeling?",
    "I'm sorry you're going through this 💙\n\nRemember, it's okay to not be okay. Your feelings are valid, and this moment will pass.\n\nWould it help to write down what you're feeling? Sometimes getting it out of your head can bring a little relief.",
  ];

  static const _anxiousResponses = [
    "I can hear that you're feeling anxious, and that's really uncomfortable 💙\n\nLet's try something: Take a slow breath in for 4 counts, hold for 4, and breathe out for 6. Repeat a few times.\n\nYou're safe right now. What's on your mind?",
    "Anxiety can feel so overwhelming, but you're not alone in this 💙\n\nTry grounding yourself: name 5 things you can see, 4 you can touch, 3 you can hear, 2 you can smell, and 1 you can taste.\n\nWhat's causing you to feel this way?",
    "I understand that feeling of worry — it's tough 💙\n\nRemember: your anxious thoughts are not facts. They're your brain trying to protect you, even when there's no real danger.\n\nWould it help to talk through what's worrying you?",
    "It's okay to feel anxious — you're not broken, you're human 💙\n\nTry placing your hand on your chest and taking 3 deep breaths. Feel your heartbeat slow down.\n\nI'm here to listen whenever you're ready to share.",
  ];

  static const _angryResponses = [
    "I can tell you're frustrated, and that's completely valid 💙\n\nAnger often comes from our boundaries being crossed or our needs not being met. It's a signal, not a weakness.\n\nWant to tell me what happened?",
    "It makes sense that you'd feel angry about this 💙\n\nYour feelings are valid. Sometimes the best thing to do is pause, take a few breaths, and then decide how you want to respond.\n\nWhat triggered this feeling?",
    "I hear your frustration, and I want you to know it's okay to feel this way 💙\n\nAnger is a natural emotion — what matters is how we process it. Would it help to talk through the situation?",
  ];

  static const _stressedResponses = [
    "It sounds like you're carrying a lot right now 💙\n\nRemember, you don't have to do everything at once. Try picking just one small thing to focus on, and give yourself permission to let the rest wait.\n\nWhat's the biggest thing on your plate?",
    "Being overwhelmed is exhausting, and I'm sorry you're feeling this way 💙\n\nTake a moment to breathe. You've handled tough things before, and you'll get through this too.\n\nWould it help to list out what's stressing you? Sometimes organizing it makes it feel more manageable.",
    "You deserve a break, even if it's just five minutes 💙\n\nStep away from what's stressing you, stretch, drink some water. Small resets can make a big difference.\n\nWhat's been the most overwhelming part?",
  ];

  static const _lonelyResponses = [
    "I'm here with you, and you're not as alone as it might feel right now 💙\n\nLoneliness is one of the most painful feelings, and it's brave of you to talk about it.\n\nIs there someone in your life — even someone you haven't talked to in a while — you could reach out to today?",
    "Feeling lonely can be so heavy, and I'm sorry you're experiencing this 💙\n\nConnection doesn't have to be big — even a small text to someone or a walk outside can help.\n\nWould you like to talk about what's making you feel isolated?",
    "You matter, and your presence in this world is valuable 💙\n\nLoneliness doesn't mean you're unwanted — sometimes life just creates distance. But bridges can be rebuilt.\n\nWhat would make you feel more connected right now?",
  ];

  static const _happyResponses = [
    "That's wonderful to hear! 🌟\n\nI love that you're sharing the good moments too. Celebrating small wins is so important for our wellbeing.\n\nWhat made today feel so great?",
    "I'm so happy for you! 😊\n\nPositive moments like these are worth savoring. Try taking a mental snapshot of how you feel right now — you can come back to it on harder days.\n\nWhat's bringing you joy?",
    "That's amazing! Your happiness is contagious 🌿\n\nRemember this feeling — it's proof that good things happen, even when life gets tough sometimes.\n\nKeep riding this wave! What else is going well?",
  ];

  static const _gratitudeResponses = [
    "You're so welcome! It means a lot that I can be here for you 💙\n\nRemember, you can come back anytime — I'm always here to listen.\n\nHow are you feeling right now?",
    "I'm really glad I could help! 💙\n\nYour willingness to open up takes real courage. Keep being kind to yourself.\n\nIs there anything else on your mind?",
    "Thank YOU for trusting me with your thoughts 💙\n\nIt's a privilege to be part of your wellness journey. Keep taking those small steps forward.\n\nAnything else you'd like to talk about?",
  ];

  static const _sleepResponses = [
    "Sleep troubles can really affect everything else 💙\n\nHere's something to try: dim your lights an hour before bed, put your phone face-down, and do some deep breathing.\n\nHave you noticed any patterns with your sleep difficulties?",
    "Not being able to sleep is so frustrating 💙\n\nTry a body scan: starting from your toes, consciously relax each muscle group all the way up to your head. It can help calm your nervous system.\n\nWhat's usually on your mind when you can't sleep?",
    "Your body and mind both need rest, and I'm sorry you're struggling with this 💙\n\nAvoid screens 30 minutes before bed, keep your room cool, and try listening to calming sounds.\n\nWould you like to tell me more about what's keeping you up?",
  ];

  static const _greetingResponses = [
    "Hey there! I'm glad you're here 💙\n\nI'm Serenity, your wellness companion. I'm currently in offline mode, so my responses are limited — but I'm still here to listen!\n\nHow are you feeling today?",
    "Hello! Welcome back 🌿\n\nI'm in offline mode right now, but I'm still here for you with some supportive words.\n\nWhat's on your mind today?",
    "Hi! It's good to see you 💙\n\nI'm running in offline mode, so I have a more limited set of responses. But your feelings still matter, and I'm here.\n\nHow has your day been?",
  ];

  static const _defaultResponses = [
    "Thank you for sharing that with me 💙\n\nI'm currently in offline mode, so my responses are limited. But I'm still here to listen, and everything you share will be saved.\n\nWhen you're back online, I'll be able to give you a more thoughtful response. How are you feeling right now?",
    "I appreciate you opening up 💙\n\nI'm in offline mode right now, but I want you to know — your thoughts and feelings are valid, no matter what.\n\nKeep talking to me; it all gets saved and I'll catch up when we're back online.",
    "I hear you, and I'm here for you 💙\n\nI'm currently offline, so I have limited responses. But remember: just putting your feelings into words is a powerful act of self-care.\n\nWhat else is on your mind?",
    "Your words matter, even when I'm offline 💙\n\nI may not be able to give my fullest response right now, but everything you share is being saved.\n\nTake a deep breath and know that you're doing something great by talking about what you feel.",
    "I want you to know that I'm listening 💙\n\nI'm in offline mode, so I can't give you my best thoughtful response, but I'm still here.\n\nRemember to be kind to yourself today. Is there more you'd like to share?",
  ];

  // ==================== Helpers ====================

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  static String _pickRandom(List<String> list) {
    return list[_random.nextInt(list.length)];
  }
}
