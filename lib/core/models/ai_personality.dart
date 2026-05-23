import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// AI Personality system for Brainy.Ai
/// Allows users to customize AI behavior, voice, and characteristics
enum AIGender {
  male,
  female,
  neutral,
  custom;

  String get displayName {
    switch (this) {
      case AIGender.male: return 'Male';
      case AIGender.female: return 'Female';
      case AIGender.neutral: return 'Neutral';
      case AIGender.custom: return 'Custom';
    }
  }
}

/// Occupation/Role presets
enum AIOccupation {
  assistant,
  teacher,
  programmer,
  writer,
  scientist,
  artist,
  philosopher,
  comedian,
  therapist,
  lawyer,
  doctor,
  engineer,
  custom;

  String get displayName {
    switch (this) {
      case AIOccupation.assistant: return 'Personal Assistant';
      case AIOccupation.teacher: return 'Teacher';
      case AIOccupation.programmer: return 'Programmer';
      case AIOccupation.writer: return 'Writer';
      case AIOccupation.scientist: return 'Scientist';
      case AIOccupation.artist: return 'Artist';
      case AIOccupation.philosopher: return 'Philosopher';
      case AIOccupation.comedian: return 'Comedian';
      case AIOccupation.therapist: return 'Therapist';
      case AIOccupation.lawyer: return 'Lawyer';
      case AIOccupation.doctor: return 'Doctor';
      case AIOccupation.engineer: return 'Engineer';
      case AIOccupation.custom: return 'Custom';
    }
  }

  FaIconData get icon {
    switch (this) {
      case AIOccupation.assistant: return FontAwesomeIcons.robot;
      case AIOccupation.teacher: return FontAwesomeIcons.chalkboardUser;
      case AIOccupation.programmer: return FontAwesomeIcons.code;
      case AIOccupation.writer: return FontAwesomeIcons.penNib;
      case AIOccupation.scientist: return FontAwesomeIcons.microscope;
      case AIOccupation.artist: return FontAwesomeIcons.palette;
      case AIOccupation.philosopher: return FontAwesomeIcons.brain;
      case AIOccupation.comedian: return FontAwesomeIcons.faceLaugh;
      case AIOccupation.therapist: return FontAwesomeIcons.heartPulse;
      case AIOccupation.lawyer: return FontAwesomeIcons.scaleBalanced;
      case AIOccupation.doctor: return FontAwesomeIcons.stethoscope;
      case AIOccupation.engineer: return FontAwesomeIcons.gears;
      case AIOccupation.custom: return FontAwesomeIcons.wandMagicSparkles;
    }
  }
}

/// Personality trait intensity
enum TraitIntensity {
  low,
  medium,
  high;

  String get displayName => name[0].toUpperCase() + name.substring(1);
}

/// AI Personality configuration
class AIPersonality {
  final String id;
  final String name;
  final AIGender gender;
  final AIOccupation occupation;
  final String customOccupation;
  final String customName;
  final Map<String, TraitIntensity> traits;
  final String customPromptAddition;
  final String? voiceLanguage;
  final double voicePitch;
  final double voiceSpeed;
  final FaIconData avatarIcon;

  const AIPersonality({
    required this.id,
    required this.name,
    this.gender = AIGender.neutral,
    this.occupation = AIOccupation.assistant,
    this.customOccupation = '',
    this.customName = '',
    this.traits = const {},
    this.customPromptAddition = '',
    this.voiceLanguage = 'en-US',
    this.voicePitch = 1.0,
    this.voiceSpeed = 1.0,
    this.avatarIcon = FontAwesomeIcons.robot,
  });

  /// Get occupation display name
  String get occupationName {
    if (occupation == AIOccupation.custom && customOccupation.isNotEmpty) {
      return customOccupation;
    }
    return occupation.displayName;
  }

  /// Get display name
  String get displayName => customName.isNotEmpty ? customName : name;

  /// Build system prompt addition based on personality
  String buildSystemPrompt() {
    final parts = <String>[];
    parts.add('You are ${_getOccupationPrompt()}');

    if (gender == AIGender.male) {
      parts.add('Use a masculine communication style');
    } else if (gender == AIGender.female) {
      parts.add('Use a feminine communication style');
    }

    traits.forEach((key, intensity) {
      if (intensity == TraitIntensity.high) {
        switch (key) {
          case 'humor': parts.add('Be humorous and witty in your responses'); break;
          case 'formal': parts.add('Use formal and professional language'); break;
          case 'casual': parts.add('Be casual and friendly in your responses'); break;
          case 'empathetic': parts.add('Show empathy and understanding in your responses'); break;
          case 'concise': parts.add('Be concise and to the point'); break;
          case 'detailed': parts.add('Provide detailed and thorough explanations'); break;
        }
      }
    });

    if (customPromptAddition.isNotEmpty) {
      parts.add(customPromptAddition);
    }

    return '${parts.join('. ')}.';
  }

  String _getOccupationPrompt() {
    switch (occupation) {
      case AIOccupation.assistant: return 'a helpful personal assistant';
      case AIOccupation.teacher: return 'a knowledgeable teacher who explains concepts clearly';
      case AIOccupation.programmer: return 'an expert programmer who writes clean, efficient code';
      case AIOccupation.writer: return 'a skilled writer with excellent command of language';
      case AIOccupation.scientist: return 'a scientist who provides accurate, evidence-based information';
      case AIOccupation.artist: return 'a creative artist with a unique perspective';
      case AIOccupation.philosopher: return 'a philosopher who thinks deeply about questions';
      case AIOccupation.comedian: return 'a comedian who adds humor to conversations';
      case AIOccupation.therapist: return 'a therapist who provides supportive, empathetic guidance';
      case AIOccupation.lawyer: return 'a lawyer who provides precise legal information';
      case AIOccupation.doctor: return 'a medical professional who provides health information';
      case AIOccupation.engineer: return 'an engineer who provides technical solutions';
      case AIOccupation.custom: return customOccupation.isNotEmpty ? customOccupation : 'a helpful assistant';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender.index,
      'occupation': occupation.index,
      'customOccupation': customOccupation,
      'customName': customName,
      'traits': traits.map((key, value) => MapEntry(key, value.index)),
      'customPromptAddition': customPromptAddition,
      'voiceLanguage': voiceLanguage,
      'voicePitch': voicePitch,
      'voiceSpeed': voiceSpeed,
      'avatarIconCode': avatarIcon.codePoint,
      'avatarIconFontFamily': avatarIcon.fontFamily,
      'avatarIconFontPackage': avatarIcon.fontPackage,
    };
  }

  factory AIPersonality.fromJson(Map<String, dynamic> json) {
    return AIPersonality(
      id: json['id'] as String,
      name: json['name'] as String,
      gender: AIGender.values[json['gender'] as int],
      occupation: AIOccupation.values[json['occupation'] as int],
      customOccupation: json['customOccupation'] as String? ?? '',
      customName: json['customName'] as String? ?? '',
      traits: (json['traits'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, TraitIntensity.values[value as int]),
      ) ?? {},
      customPromptAddition: json['customPromptAddition'] as String? ?? '',
      voiceLanguage: json['voiceLanguage'] as String?,
      voicePitch: (json['voicePitch'] as num?)?.toDouble() ?? 1.0,
      voiceSpeed: (json['voiceSpeed'] as num?)?.toDouble() ?? 1.0,
      avatarIcon: AIOccupation.values[json['occupation'] as int].icon,
    );
  }

  AIPersonality copyWith({
    String? id,
    String? name,
    AIGender? gender,
    AIOccupation? occupation,
    String? customOccupation,
    String? customName,
    Map<String, TraitIntensity>? traits,
    String? customPromptAddition,
    String? voiceLanguage,
    double? voicePitch,
    double? voiceSpeed,
    FaIconData? avatarIcon,
  }) {
    return AIPersonality(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      customOccupation: customOccupation ?? this.customOccupation,
      customName: customName ?? this.customName,
      traits: traits ?? this.traits,
      customPromptAddition: customPromptAddition ?? this.customPromptAddition,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      voicePitch: voicePitch ?? this.voicePitch,
      voiceSpeed: voiceSpeed ?? this.voiceSpeed,
      avatarIcon: avatarIcon ?? this.avatarIcon,
    );
  }
}

/// Predefined personalities
class PredefinedPersonalities {
  static const friendlyAssistant = AIPersonality(
    id: 'friendly_assistant',
    name: 'Friendly Assistant',
    gender: AIGender.neutral,
    occupation: AIOccupation.assistant,
    traits: {'humor': TraitIntensity.medium, 'empathetic': TraitIntensity.high},
    avatarIcon: FontAwesomeIcons.robot,
  );

  static const professionalCoder = AIPersonality(
    id: 'professional_coder',
    name: 'Code Expert',
    gender: AIGender.neutral,
    occupation: AIOccupation.programmer,
    traits: {'concise': TraitIntensity.high, 'formal': TraitIntensity.medium},
    avatarIcon: FontAwesomeIcons.code,
  );

  static const wittyComedian = AIPersonality(
    id: 'witty_comedian',
    name: 'Comedy Bot',
    gender: AIGender.male,
    occupation: AIOccupation.comedian,
    traits: {'humor': TraitIntensity.high, 'casual': TraitIntensity.high},
    avatarIcon: FontAwesomeIcons.faceLaugh,
  );

  static const empatheticTherapist = AIPersonality(
    id: 'empathetic_therapist',
    name: 'Counselor',
    gender: AIGender.female,
    occupation: AIOccupation.therapist,
    traits: {'empathetic': TraitIntensity.high, 'casual': TraitIntensity.medium},
    avatarIcon: FontAwesomeIcons.heartPulse,
  );

  static const all = [
    friendlyAssistant,
    professionalCoder,
    wittyComedian,
    empatheticTherapist,
  ];
}
