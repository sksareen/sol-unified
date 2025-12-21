# MABLE: Problem Space Analysis

## Mission Statement
Enable humankind to progress by acting, by taking ownership and accountability, allowing them to move forward and not be passive. Starting with making easy things easy - eliminating the gap between wanting to do something and actually doing it.

## Core Problem: The Action Paralysis Loop

People have access to powerful tools (like vibe coding/AI) but get stuck in an endless cycle:
1. "I don't know what I want to do"
2. "I don't know what to do" 
3. "I don't know what's possible"
4. "There are infinite possibilities, I can't decide"
→ **Result: No action taken**

## The Three Fundamental Problems

### 1. The Knowledge Gap
- **Problem**: People don't understand how AI/LLMs fundamentally work
- **Impact**: They can't make good decisions about when/how to use different approaches
- **Manifestation**: Endless debates about "what's the best query/model" without basic literacy
- **Solution Direction**: Education through experience, not tutorials

### 2. The Context Problem  
- **Problem**: AI needs personal context to be useful, but massive context degrades performance
- **Impact**: AI either doesn't know enough about you, or knows too much and gets confused
- **Manifestation**: Generic, unhelpful responses that don't fit your specific situation
- **Solution Direction**: Intelligent context aggregation and management

### 3. The Routing Problem
- **Problem**: AI needs to dynamically select which pieces of your context are relevant for current intent
- **Impact**: Even with good context, AI can't focus on what matters right now
- **Manifestation**: Information overload, irrelevant suggestions, poor intent understanding
- **Solution Direction**: Specialized routing models (possibly local, lightweight)

## User Behavior Patterns That Kill Adoption

### The "Mind Reading" Expectation
- Users expect AI to understand everything from minimal input
- They don't iterate or collaborate with AI
- Poor initial results → "AI doesn't understand me" → abandonment
- **Root Causes**: LLM illiteracy + lack of collaboration experience

### The Specificity vs Inference Trade-off
- **Current Approach**: Make humans be more specific (Cursor's Browser)
- **MABLE Approach**: Make AI better at inference from context
- **Challenge**: Can inference be reliable enough for user trust?

## Target User: Product Managers
- Have some technical understanding but lack implementation knowledge
- Don't know Git, VSCode, deployment, hosting
- **Core Need**: Go from vague product ideas to specific, actionable requirements
- **Not**: Learning Git or server setup (tactical frictions to solve later)

## Problem Categorization

### Core Problems (Must Solve)
1. Knowledge Gap - understanding what's possible
2. Context Problem - AI knowing your situation  
3. Routing Problem - AI focusing on relevant context
4. Collaboration Patterns - users learning to work with AI iteratively

### Tactical Frictions (Solve Later)
- Git workflows
- Deployment and hosting
- Account setup
- VSCode configuration
- Data interpolation expectations

## Development Journey

### Phase 1: Minimal Viable Test
- **Goal**: Test core assumption about inference vs specificity
- **Approach**: Pick one very specific, constrained workflow
- **Success Criteria**: Users trust the inference enough to continue using it
- **Technical Approach**: 
  - Small, local routing model (not LLM-powered)
  - Limited context scope
  - Clear success/failure measurement

### Phase 2: Context Aggregation
- **Goal**: Build personal context understanding
- **Approach**: Integrate multiple data sources about user's work patterns
- **Challenge**: Balance context richness with performance

### Phase 3: Intent Understanding
- **Goal**: Reliable routing based on current user intent
- **Approach**: Specialized models for intent classification
- **Challenge**: Understanding implicit intent from minimal input

### Phase 4: Collaboration Training
- **Goal**: Train users to be better AI collaborators through the experience
- **Approach**: Make iteration feel natural and rewarding
- **Challenge**: Changing user expectations from "mind reading" to "collaboration"

### Phase 5: Scale and Expand
- **Goal**: Move beyond PMs to broader user base
- **Approach**: Apply learnings to different domains and workflows
- **Challenge**: Maintaining inference quality across diverse use cases

## Key Design Principles

1. **Inference over Specificity**: Make AI smarter, not users more precise
2. **Local where Possible**: Routing and performance-critical components should run locally
3. **Context-Aware**: Deep understanding of user's personal work patterns
4. **Collaboration-First**: Train users to iterate and refine through positive feedback loops
5. **Action-Oriented**: Always move toward concrete next steps, not endless analysis

## Success Metrics

### User Behavior
- Reduced time from idea to first action
- Increased iteration cycles with AI
- Higher task completion rates
- Sustained usage over time

### Technical Performance  
- Context relevance accuracy
- Intent classification success rate
- Response time (especially for local routing)
- User trust in AI suggestions

### Business Impact
- User retention and engagement
- Expansion from PM target to broader audiences
- Reduction in "AI doesn't understand me" churn